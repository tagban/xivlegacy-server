// garlemald-server — Rust port of a FINAL FANTASY XIV v1.23b server emulator (lobby/world/map)
// Copyright (C) 2026  Samuel Stegall
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! The optional HTTPS listener (`[tls]` in web.toml). The plain HTTP port
//! keeps running beside it, so servers without TLS and older launchers work.

use std::net::SocketAddr;
use std::time::Duration;

use anyhow::{Context, Result, bail};
use axum::Router;
use axum_server::tls_rustls::RustlsConfig;
use futures::StreamExt;
use rustls_acme::AcmeConfig;
use rustls_acme::caches::DirCache;

use crate::config::TlsSection;

pub async fn serve(tls: TlsSection, bind_ip: &str, app: Router) -> Result<()> {
    // One crypto back end for the whole process (ring builds everywhere we ship).
    let _ = rustls::crypto::ring::default_provider().install_default();
    let addr: SocketAddr = format!("{bind_ip}:{}", tls.port)
        .parse()
        .with_context(|| format!("parsing HTTPS address {bind_ip}:{}", tls.port))?;
    let make = app.into_make_service();
    if !tls.cert_file.is_empty() {
        if tls.key_file.is_empty() {
            bail!("[tls] cert_file is set but key_file isn't");
        }
        let config = RustlsConfig::from_pem_file(&tls.cert_file, &tls.key_file)
            .await
            .with_context(|| format!("loading {} / {}", tls.cert_file, tls.key_file))?;
        // Pick up a renewed certificate without a restart.
        let (reload, cert, key) = (config.clone(), tls.cert_file.clone(), tls.key_file.clone());
        tokio::spawn(async move {
            loop {
                tokio::time::sleep(Duration::from_secs(12 * 3600)).await;
                if let Err(e) = reload.reload_from_pem_file(&cert, &key).await {
                    tracing::warn!("reloading {cert}: {e}");
                }
            }
        });
        tracing::info!(%addr, cert = %tls.cert_file, "HTTPS listening (certificate files)");
        axum_server::bind_rustls(addr, config).serve(make).await?;
        return Ok(());
    }
    let mut state = AcmeConfig::new(tls.domains.clone())
        .contact(tls.contact.iter().map(|e| format!("mailto:{e}")))
        .cache(DirCache::new(tls.cache_dir.clone()))
        .directory_lets_encrypt(!tls.staging)
        .state();
    let acceptor = state.axum_acceptor(state.default_rustls_config());
    tokio::spawn(async move {
        while let Some(event) = state.next().await {
            match event {
                Ok(ok) => tracing::info!("certificate: {ok:?}"),
                Err(err) => {
                    tracing::warn!("certificate: {err}");
                    tokio::time::sleep(Duration::from_secs(5)).await;
                }
            }
        }
    });
    tracing::info!(%addr, domains = ?tls.domains, staging = tls.staging, "HTTPS listening (Let's Encrypt)");
    axum_server::bind(addr)
        .acceptor(acceptor)
        .serve(make)
        .await?;
    Ok(())
}
