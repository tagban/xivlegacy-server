//! Ground height from the operator's own FFXIV 1.23b install, read at run
//! time (a port of `tools/terrain/xivterrain.py`; nothing from the client
//! is stored in the repo). An area's MapLayout file places collision meshes
//! (PHB files) in the world; floors are the up-facing triangles under a
//! point. Layout coordinates are server world coordinates.
//!
//! Only field zones are answered (`*Field*`): town and dungeon coordinates
//! don't line up with their layouts yet (tools/terrain/README.md).
//!
//! The install is found from `XIVLEGACY_CLIENT_DIR`, then `XIV_CLIENT`.
//! Without one every query answers `None` and callers keep their height.
//! Areas load on a blocking thread the first time a zone is asked about;
//! until then the zone answers `Loading`.

use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, OnceLock};

/// Triangle bucket size (yalms).
const CELL: f32 = 8.0;
/// A floor's normal must point at least this much up (cos of ~78 degrees).
const MIN_UP: f32 = 0.2;

/// What a ground query found.
#[derive(Debug, Clone, PartialEq)]
pub enum Floors {
    /// The zone's collision is loaded: every floor height, low to high
    /// (empty off the mesh).
    Known(Vec<f32>),
    /// The zone is loading (or has no layout, or no client is set up).
    Unknown,
}

type Mat = [[f32; 4]; 3];

fn matrix(pos: [f32; 3], rot: [f32; 3], scale: [f32; 3]) -> Mat {
    let (cx, sx) = (rot[0].cos(), rot[0].sin());
    let (cy, sy) = (rot[1].cos(), rot[1].sin());
    let (cz, sz) = (rot[2].cos(), rot[2].sin());
    let r = [
        [cz * cy, cz * sy * sx - sz * cx, cz * sy * cx + sz * sx],
        [sz * cy, sz * sy * sx + cz * cx, sz * sy * cx - cz * sx],
        [-sy, cy * sx, cy * cx],
    ];
    let mut m = [[0.0; 4]; 3];
    for i in 0..3 {
        m[i] = [
            r[i][0] * scale[0],
            r[i][1] * scale[1],
            r[i][2] * scale[2],
            pos[i],
        ];
    }
    m
}

fn compose(a: &Mat, b: &Mat) -> Mat {
    let mut m = [[0.0; 4]; 3];
    for i in 0..3 {
        for j in 0..4 {
            let mut s: f32 = (0..3).map(|k| a[i][k] * b[k][j]).sum();
            if j == 3 {
                s += a[i][3];
            }
            m[i][j] = s;
        }
    }
    m
}

fn apply(m: &Mat, v: [f32; 3]) -> [f32; 3] {
    let row = |i: usize| m[i][0] * v[0] + m[i][1] * v[1] + m[i][2] * v[2] + m[i][3];
    [row(0), row(1), row(2)]
}

fn find(hay: &[u8], needle: &[u8], from: usize, to: usize) -> Option<usize> {
    let to = to.min(hay.len());
    if from >= to || needle.len() > to - from {
        return None;
    }
    hay[from..to]
        .windows(needle.len())
        .position(|w| w == needle)
        .map(|p| p + from)
}

fn u32_at(d: &[u8], o: usize) -> Option<u32> {
    d.get(o..o + 4)
        .map(|b| u32::from_le_bytes([b[0], b[1], b[2], b[3]]))
}

fn u16_at(d: &[u8], o: usize) -> Option<u16> {
    d.get(o..o + 2).map(|b| u16::from_le_bytes([b[0], b[1]]))
}

fn f32_at(d: &[u8], o: usize) -> Option<f32> {
    u32_at(d, o).map(f32::from_bits)
}

fn vec3_at(d: &[u8], o: usize) -> Option<[f32; 3]> {
    Some([f32_at(d, o)?, f32_at(d, o + 4)?, f32_at(d, o + 8)?])
}

/// Server zone name -> layout area name: `sea0Field01` -> `sea_s0_fld01`.
/// Field zones only (see the module note).
pub fn area_name(zone_name: &str) -> Option<String> {
    let b = zone_name.as_bytes();
    if b.len() < 6 || !b[..3].iter().all(u8::is_ascii_lowercase) || !b[3].is_ascii_digit() {
        return None;
    }
    let rest = &zone_name[4..];
    let split = rest.find(|c: char| c.is_ascii_digit())?;
    let (kind, num) = rest.split_at(split);
    if kind != "Field" || num.is_empty() || !num.bytes().all(|c| c.is_ascii_digit()) {
        return None;
    }
    let num: u32 = num.parse().ok()?;
    let reg = &zone_name[..3];
    Some(format!(
        "{reg}_{}{}_fld{num:02}",
        &reg[..1],
        &zone_name[3..4]
    ))
}

/// One MapLayout file: its resource table and its collision placements.
struct Layout {
    resources: HashMap<String, HashMap<String, u32>>,
    blob: Vec<u8>,
    classes: HashMap<u32, String>,
}

impl Layout {
    fn parse(data: &[u8]) -> Option<Self> {
        let count = u32_at(data, 0x24)? as usize;
        let mut resources: HashMap<String, HashMap<String, u32>> = HashMap::new();
        for i in 0..count {
            let o = 0x60 + 32 * i;
            let raw = data.get(o..o + 24)?;
            let key = cstr(&raw[..16]);
            let typ: String = cstr(&raw[16..20]).chars().rev().collect();
            let rid = u32_at(data, o + 20)?;
            resources.entry(key).or_default().insert(typ, rid);
        }
        let base = find(data, b"SEDBlyb", 0, data.len())? + 0x30;
        let len = u32_at(data, base + 4)? as usize;
        let blob = data.get(base..(base + len).min(data.len()))?.to_vec();
        let mut l = Layout {
            resources,
            blob,
            classes: HashMap::new(),
        };
        let n = l.blob.len() / 4;
        for i in 0..n.saturating_sub(4) {
            if l.w(i + 1) == Some(0)
                && l.w(i + 3) == Some(0)
                && let Some(name) = l.string(l.w(i + 2).unwrap_or(0))
            {
                let plain = name.replace(['/', '_'], "");
                if name.contains('/')
                    && name.starts_with(|c: char| c.is_ascii_uppercase())
                    && !plain.is_empty()
                    && plain.chars().all(|c| c.is_ascii_alphanumeric())
                {
                    let short = name.rsplit('/').next().unwrap_or("").to_string();
                    l.classes.insert((4 * i) as u32, short);
                }
            }
        }
        Some(l)
    }

    fn w(&self, i: usize) -> Option<u32> {
        u32_at(&self.blob, 4 * i)
    }

    fn word(&self, off: u32, k: usize) -> Option<u32> {
        self.w(off as usize / 4 + k)
    }

    fn vec(&self, off: u32) -> Option<[f32; 3]> {
        let i = off as usize / 4;
        Some([
            f32::from_bits(self.w(i)?),
            f32::from_bits(self.w(i + 1)?),
            f32::from_bits(self.w(i + 2)?),
        ])
    }

    fn string(&self, off: u32) -> Option<String> {
        let off = off as usize;
        if off == 0 || off >= self.blob.len() {
            return None;
        }
        let end = find(&self.blob, b"\0", off, self.blob.len())?;
        (end - off < 100).then(|| self.blob[off..end].iter().map(|&b| b as char).collect())
    }

    fn class_of(&self, off: u32) -> Option<&str> {
        self.classes.get(&self.word(off, 1)?).map(String::as_str)
    }

    /// (PHB DAT id, world matrix, resource key) for every placed collision
    /// mesh: attribute objects, and models whose resource key has a phb.
    fn collision(&self) -> Vec<(u32, Mat, String)> {
        let inst: std::collections::HashSet<u32> = self
            .classes
            .iter()
            .filter(|(_, v)| *v == "InstanceObject")
            .map(|(k, _)| *k)
            .collect();
        let n = self.blob.len() / 4;
        let mut out = Vec::new();
        for i in 1..n.saturating_sub(16) {
            if !self.w(i).is_some_and(|v| inst.contains(&v)) {
                continue;
            }
            let o = (4 * (i - 1)) as u32;
            let Some(parts) = (|| {
                let pos = [
                    f32::from_bits(self.word(o, 8)?),
                    f32::from_bits(self.word(o, 9)?),
                    f32::from_bits(self.word(o, 10)?),
                ];
                let m = matrix(
                    pos,
                    self.vec(self.word(o, 11)?)?,
                    self.vec(self.word(o, 12)?)?,
                );
                let base = self.word(o, 15)?;
                if self.class_of(base) == Some("UnitTreeObject") {
                    let (arr, n) = (self.word(base, 12)?, self.word(base, 13)?);
                    let mut parts = Vec::new();
                    for k in 0..n.min(100_000) {
                        let e = arr.checked_add(0x30 * k)?;
                        let local = matrix(
                            [
                                f32::from_bits(self.word(e, 0)?),
                                f32::from_bits(self.word(e, 1)?),
                                f32::from_bits(self.word(e, 2)?),
                            ],
                            self.vec(self.word(e, 3)?)?,
                            self.vec(self.word(e, 4)?)?,
                        );
                        parts.push((self.word(e, 6)?, compose(&m, &local)));
                    }
                    Some(parts)
                } else {
                    Some(vec![(base, m)])
                }
            })() else {
                continue;
            };
            for (obj, mat) in parts {
                let key = match self.class_of(obj) {
                    Some("AttributeBaseObject") => self.word(obj, 9).and_then(|w| self.string(w)),
                    Some("BGPartsBaseObject" | "BGChipBaseObject") => {
                        self.word(obj, 8).and_then(|w| self.string(w))
                    }
                    _ => None,
                };
                let Some(key) = key else { continue };
                if let Some(&rid) = self.resources.get(&key).and_then(|r| r.get("phb")) {
                    out.push((rid, mat, key));
                }
            }
        }
        out
    }
}

fn cstr(b: &[u8]) -> String {
    b.iter()
        .take_while(|&&c| c != 0)
        .map(|&c| c as char)
        .collect()
}

/// A PHB collision mesh: vertices and triangles.
struct Phb {
    verts: Vec<[f32; 3]>,
    tris: Vec<[u16; 3]>,
}

fn read_phb(data: &[u8]) -> Option<Phb> {
    let g = find(data, b"PHB.GBD", 0, data.len())?;
    let h = |k: usize| u32_at(data, g + 8 + 4 * k).map(|v| v as usize);
    let (o_tbc, l_tbc, o_verts, n_verts) = (h(9)?, h(10)?, h(12)?, h(13)?);
    let (mut n_tris, mut i, end) = (0usize, g + o_tbc, g + o_tbc + l_tbc);
    while let Some(at) = find(data, b"PHB.TBD", i, end) {
        let n = u32_at(data, at + 20)? as usize;
        let o_list = u32_at(data, at + 24)? as usize;
        for k in 0..n {
            n_tris = n_tris.max(usize::from(u16_at(data, at + o_list + 2 * k)?) + 1);
        }
        i = at + 8;
    }
    let verts = (0..n_verts)
        .map(|k| vec3_at(data, g + o_verts + 12 * k))
        .collect::<Option<Vec<_>>>()?;
    let t0 = (g + o_verts).checked_sub((8 * n_tris + 0x7F) & !0x7F)?;
    let tris = (0..n_tris)
        .map(|k| {
            let o = t0 + 8 * k;
            Some([u16_at(data, o)?, u16_at(data, o + 2)?, u16_at(data, o + 4)?])
        })
        .collect::<Option<Vec<_>>>()?;
    Some(Phb { verts, tris })
}

fn cell_of(x: f32, z: f32) -> (i32, i32) {
    ((x / CELL).floor() as i32, (z / CELL).floor() as i32)
}

/// One area's floors (props left out), bucketed by cell.
pub struct Area {
    cells: HashMap<(i32, i32), Vec<[f32; 9]>>,
}

impl Area {
    fn load(data_dir: &Path, layout: &[u8]) -> Option<Self> {
        let layout = Layout::parse(layout)?;
        let mut meshes: HashMap<u32, Option<Phb>> = HashMap::new();
        let mut cells: HashMap<(i32, i32), Vec<[f32; 9]>> = HashMap::new();
        for (rid, m, key) in layout.collision() {
            // Scaled primitive colliders ("......col_cyln04_a"): tree
            // trunks, crates, posts.
            if key.get(6..).is_some_and(|k| k.starts_with("col_")) {
                continue;
            }
            let phb = meshes.entry(rid).or_insert_with(|| {
                std::fs::read(dat_path(data_dir, rid))
                    .ok()
                    .and_then(|d| read_phb(&d))
            });
            let Some(phb) = phb else { continue };
            let w: Vec<[f32; 3]> = phb.verts.iter().map(|&v| apply(&m, v)).collect();
            for t in &phb.tris {
                let (Some(a), Some(b), Some(c)) = (
                    w.get(usize::from(t[0])),
                    w.get(usize::from(t[1])),
                    w.get(usize::from(t[2])),
                ) else {
                    continue;
                };
                let u = [b[0] - a[0], b[1] - a[1], b[2] - a[2]];
                let v = [c[0] - a[0], c[1] - a[1], c[2] - a[2]];
                let n = [
                    u[1] * v[2] - u[2] * v[1],
                    u[2] * v[0] - u[0] * v[2],
                    u[0] * v[1] - u[1] * v[0],
                ];
                let ln = (n[0] * n[0] + n[1] * n[1] + n[2] * n[2]).sqrt();
                if ln == 0.0 || n[1] / ln < MIN_UP {
                    continue;
                }
                let tri = [a[0], a[1], a[2], b[0], b[1], b[2], c[0], c[1], c[2]];
                let (lo, hi) = (
                    cell_of(a[0].min(b[0]).min(c[0]), a[2].min(b[2]).min(c[2])),
                    cell_of(a[0].max(b[0]).max(c[0]), a[2].max(b[2]).max(c[2])),
                );
                for cx in lo.0..=hi.0 {
                    for cz in lo.1..=hi.1 {
                        cells.entry((cx, cz)).or_default().push(tri);
                    }
                }
            }
        }
        Some(Area { cells })
    }

    /// Every floor height under (x, z), low to high.
    pub fn floors(&self, x: f32, z: f32) -> Vec<f32> {
        let mut out = Vec::new();
        for t in self.cells.get(&cell_of(x, z)).into_iter().flatten() {
            let [ax, ay, az, bx, by, bz, cx, cy, cz] = *t;
            let d = (bx - ax) * (cz - az) - (cx - ax) * (bz - az);
            if d == 0.0 {
                continue;
            }
            let u = ((x - ax) * (cz - az) - (cx - ax) * (z - az)) / d;
            let v = ((bx - ax) * (z - az) - (x - ax) * (bz - az)) / d;
            if u < -1e-6 || v < -1e-6 || u + v > 1.0 + 1e-6 {
                continue;
            }
            out.push(ay + u * (by - ay) + v * (cy - ay));
        }
        out.sort_by(f32::total_cmp);
        // The same floor often comes from several overlapping meshes.
        let mut dedup: Vec<f32> = Vec::with_capacity(out.len());
        for y in out {
            if dedup.last().is_none_or(|l| y - l > 0.05) {
                dedup.push(y);
            }
        }
        dedup
    }
}

fn dat_path(data: &Path, rid: u32) -> PathBuf {
    data.join(format!(
        "{:02X}/{:02X}/{:02X}/{:02X}.DAT",
        rid >> 24,
        (rid >> 16) & 255,
        (rid >> 8) & 255,
        rid & 255
    ))
}

enum Slot {
    Loading,
    Ready(Option<Arc<Area>>),
}

struct Terrain {
    data: PathBuf,
    layouts: OnceLock<HashMap<String, PathBuf>>,
    areas: Mutex<HashMap<String, Slot>>,
}

impl Terrain {
    fn cache_path() -> PathBuf {
        let base = std::env::var_os("XDG_CACHE_HOME")
            .map(PathBuf::from)
            .or_else(|| std::env::var_os("HOME").map(|h| PathBuf::from(h).join(".cache")))
            .unwrap_or_else(|| PathBuf::from(".cache"));
        base.join("xivlegacy").join("terrain_layouts.json")
    }

    /// Area name -> MapLayout path: the Python tool's cache, else a scan of
    /// the first bytes of every DAT (about 40 s cold), then cached.
    fn layouts(&self) -> &HashMap<String, PathBuf> {
        self.layouts.get_or_init(|| {
            let cache = Self::cache_path();
            if let Ok(text) = std::fs::read_to_string(&cache)
                && let Ok(v) = serde_json::from_str::<serde_json::Value>(&text)
                && v.get("data").and_then(|d| d.as_str()) == self.data.to_str()
                && let Some(map) = v.get("layouts").and_then(|l| l.as_object())
            {
                return map
                    .iter()
                    .filter_map(|(k, p)| Some((k.clone(), self.data.join(p.as_str()?))))
                    .collect();
            }
            let mut found: HashMap<String, PathBuf> = HashMap::new();
            let mut paths = Vec::new();
            collect_dats(&self.data, 0, &mut paths);
            paths.sort();
            for path in paths {
                use std::io::Read;
                let Ok(mut f) = std::fs::File::open(&path) else {
                    continue;
                };
                let mut head = [0u8; 21];
                if f.read_exact(&mut head).is_err() || &head != b"MapLayoutResourceData" {
                    continue;
                }
                let mut buf = vec![0u8; 0x20000];
                let n = f.read(&mut buf).unwrap_or(0);
                buf.truncate(n);
                if let Some(i) = find(&buf, b"Root Folder\0", 0, buf.len()) {
                    let name = cstr(&buf[i + 12..]);
                    found.entry(name).or_insert(path);
                }
            }
            let rel: serde_json::Map<String, serde_json::Value> = found
                .iter()
                .filter_map(|(k, p)| {
                    let r = p.strip_prefix(&self.data).ok()?.to_str()?.to_string();
                    Some((k.clone(), serde_json::Value::String(r)))
                })
                .collect();
            let doc = serde_json::json!({ "data": self.data.to_str(), "layouts": rel });
            if let Some(dir) = cache.parent() {
                let _ = std::fs::create_dir_all(dir);
            }
            let _ = std::fs::write(&cache, doc.to_string());
            found
        })
    }
}

fn collect_dats(dir: &Path, depth: u8, out: &mut Vec<PathBuf>) {
    let Ok(rd) = std::fs::read_dir(dir) else {
        return;
    };
    for e in rd.flatten() {
        let p = e.path();
        if depth < 3 {
            if p.is_dir() {
                collect_dats(&p, depth + 1, out);
            }
        } else if p.extension().is_some_and(|x| x.eq_ignore_ascii_case("dat")) {
            out.push(p);
        }
    }
}

fn terrain() -> Option<&'static Arc<Terrain>> {
    static T: OnceLock<Option<Arc<Terrain>>> = OnceLock::new();
    T.get_or_init(|| {
        let dir = std::env::var_os("XIVLEGACY_CLIENT_DIR").or_else(|| std::env::var_os("XIV_CLIENT"))?;
        let data = PathBuf::from(dir).join("data");
        if !data.is_dir() {
            tracing::warn!(path = %data.display(), "terrain: no 1.23b data folder; knockback keeps height");
            return None;
        }
        tracing::info!(path = %data.display(), "terrain: ground heights from the client install");
        Some(Arc::new(Terrain {
            data,
            layouts: OnceLock::new(),
            areas: Mutex::new(HashMap::new()),
        }))
    })
    .as_ref()
}

/// Every floor under (x, z) in the zone named `zone_name`, or `Unknown`
/// while it loads (the first call starts the load on a blocking thread)
/// and where no answer is possible.
pub fn floors(zone_name: &str, x: f32, z: f32) -> Floors {
    let Some(t) = terrain() else {
        return Floors::Unknown;
    };
    let Some(name) = area_name(zone_name) else {
        return Floors::Unknown;
    };
    let mut areas = match t.areas.lock() {
        Ok(a) => a,
        Err(_) => return Floors::Unknown,
    };
    match areas.get(&name) {
        Some(Slot::Ready(Some(a))) => Floors::Known(a.floors(x, z)),
        Some(Slot::Ready(None)) | Some(Slot::Loading) => Floors::Unknown,
        None => {
            areas.insert(name.clone(), Slot::Loading);
            let t = t.clone();
            std::thread::spawn(move || {
                let area = t
                    .layouts()
                    .get(&name)
                    .and_then(|p| std::fs::read(p).ok())
                    .and_then(|d| Area::load(&t.data, &d))
                    .map(Arc::new);
                tracing::info!(area = %name, loaded = area.is_some(), "terrain: area loaded");
                if let Ok(mut a) = t.areas.lock() {
                    a.insert(name, Slot::Ready(area));
                }
            });
            Floors::Unknown
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn area_names_match_the_python_tool() {
        assert_eq!(area_name("sea0Field01").as_deref(), Some("sea_s0_fld01"));
        assert_eq!(area_name("fst0Field03").as_deref(), Some("fst_f0_fld03"));
        assert_eq!(area_name("wil0Town01"), None, "towns aren't trusted");
        assert_eq!(area_name(""), None);
    }

    #[test]
    fn floors_of_one_triangle() {
        let mut cells = HashMap::new();
        // A flat triangle at y = 5 over (0..8, 0..8).
        cells.insert((0, 0), vec![[0.0, 5.0, 0.0, 8.0, 5.0, 0.0, 0.0, 5.0, 8.0]]);
        let a = Area { cells };
        assert_eq!(a.floors(1.0, 1.0), vec![5.0]);
        assert!(a.floors(7.0, 7.0).is_empty(), "outside the triangle");
    }

    #[test]
    fn matrix_places_points() {
        let m = matrix([1.0, 2.0, 3.0], [0.0, 0.0, 0.0], [2.0, 2.0, 2.0]);
        assert_eq!(apply(&m, [1.0, 1.0, 1.0]), [3.0, 4.0, 5.0]);
        let id = matrix([0.0; 3], [0.0; 3], [1.0; 3]);
        assert_eq!(compose(&m, &id), m);
    }

    /// Needs the 1.23b install: `XIV_CLIENT=... cargo test terrain -- --ignored`.
    /// Heights from `tools/terrain/xivterrain.py` for the same points.
    #[test]
    #[ignore]
    fn matches_the_python_tool_in_lower_la_noscea() {
        let dir = std::env::var_os("XIV_CLIENT").expect("XIV_CLIENT");
        let data = PathBuf::from(dir).join("data");
        let t = Terrain {
            data: data.clone(),
            layouts: OnceLock::new(),
            areas: Mutex::new(HashMap::new()),
        };
        let path = t.layouts().get("sea_s0_fld01").expect("layout").clone();
        let area = Area::load(&data, &std::fs::read(path).unwrap()).expect("area");
        for (x, z, want) in [
            (151.635, 59.928, vec![45.399]),
            (100.0, 100.0, vec![43.115]),
            (-50.5, 210.25, vec![0.0]),
            (15.51, 84.32, vec![43.045]),
            (200.0, -300.0, vec![]),
            (0.0, 0.0, vec![46.5]),
        ] {
            let got = area.floors(x, z);
            assert_eq!(got.len(), want.len(), "({x}, {z}): {got:?} vs {want:?}");
            for (g, w) in got.iter().zip(&want) {
                assert!((g - w).abs() < 0.01, "({x}, {z}): {got:?} vs {want:?}");
            }
        }
    }
}
