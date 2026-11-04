// XIVLegacy Server — FINAL FANTASY XIV v1.23b server (lobby/world/map)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! MariaDB access for every server.
//!
//! The servers were written against rusqlite, so this module keeps the
//! small part of rusqlite's API they use (`call_db`, `execute`,
//! `query_row`, `prepare` + `query_map`, `transaction`, `named_params!`,
//! `r.get::<_, T>(i)`) and runs it on MariaDB through the `mysql` crate.
//! Query code moves over by changing its SQL, not its structure.
//!
//! Each [`Connection`] owns one MariaDB connection on one worker thread
//! and runs the closures sent to it in order, exactly as tokio_rusqlite
//! did. That ordering matters: a save queued after another save must not
//! land before it.
//!
//! Every session runs with standard SQL quoting (`ANSI_QUOTES`, so
//! `"name"` is an identifier; `PIPES_AS_CONCAT`, so `||` joins strings),
//! strict types, `NO_AUTO_VALUE_ON_ZERO` (an explicit id 0 is stored as
//! 0), and `CLIENT_FOUND_ROWS`, so an UPDATE reports the rows it matched
//! as SQLite did, not only the rows whose values changed.

use std::cell::RefCell;
use std::collections::HashMap;
use std::sync::Arc;
use std::sync::mpsc;
use std::time::Duration;

use mysql::prelude::Queryable;

/// The session settings every connection runs with (see the module docs).
pub const SQL_MODE: &str = "ANSI_QUOTES,PIPES_AS_CONCAT,STRICT_ALL_TABLES,\
NO_AUTO_VALUE_ON_ZERO,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION";

pub type Result<T, E = Error> = std::result::Result<T, E>;

/// Where the servers look when no database URL is configured.
pub const DEFAULT_URL: &str = "mysql://xivlegacy@127.0.0.1:3306/xivlegacy";

/// The database URL to use: `XIVLEGACY_DB_URL` from the environment when
/// set, else the configured one.
pub fn configured_url(configured: &str) -> String {
    match std::env::var("XIVLEGACY_DB_URL") {
        Ok(u) if !u.trim().is_empty() => u.trim().to_string(),
        _ => configured.to_string(),
    }
}

/// A database URL with its password replaced, for logs.
pub fn redact(url: &str) -> String {
    match (url.find("://"), url.rfind('@')) {
        (Some(s), Some(at)) if at > s => {
            let creds = &url[s + 3..at];
            match creds.split_once(':') {
                Some((user, _)) => format!("{}{user}:***{}", &url[..s + 3], &url[at..]),
                None => url.to_string(),
            }
        }
        _ => url.to_string(),
    }
}

/// A database error, shaped like the rusqlite errors the code matches on.
#[derive(Debug, thiserror::Error)]
pub enum Error {
    /// `query_row` found no row (rusqlite's `QueryReturnedNoRows`).
    #[error("query returned no rows")]
    QueryReturnedNoRows,
    /// A column could not be read as the Rust type asked for.
    #[error("column {index}: {message}")]
    Conversion { index: usize, message: String },
    /// A named column that the row doesn't have.
    #[error("no column named {0}")]
    InvalidColumnName(String),
    /// A column index past the end of the row.
    #[error("no column at index {0}")]
    InvalidColumnIndex(usize),
    /// An error from MariaDB or the connection.
    #[error(transparent)]
    Mysql(#[from] mysql::Error),
    /// Anything else (a closed worker, a bad URL, a failed migration file).
    #[error("{0}")]
    Other(String),
}

impl Error {
    /// The MariaDB error number, when MariaDB returned one.
    pub fn server_code(&self) -> Option<u16> {
        match self {
            Error::Mysql(mysql::Error::MySqlError(e)) => Some(e.code),
            _ => None,
        }
    }

    /// A duplicate key, a missing foreign row, or a NULL in a NOT NULL
    /// column: what SQLite reported as a constraint violation.
    pub fn is_constraint_violation(&self) -> bool {
        matches!(
            self.server_code(),
            Some(1062 | 1048 | 1451 | 1452 | 1216 | 1217 | 4025)
        )
    }

    /// The table or column a statement names doesn't exist yet.
    pub fn is_missing_table_or_column(&self) -> bool {
        matches!(self.server_code(), Some(1146 | 1054))
    }
}

impl From<String> for Error {
    fn from(s: String) -> Self {
        Error::Other(s)
    }
}

// ---------------------------------------------------------------------------
// Values in

/// A Rust value that can be bound as a statement parameter.
pub trait ToSql {
    fn to_sql(&self) -> Result<mysql::Value>;
}

macro_rules! to_sql_int {
    ($($t:ty),*) => {$(
        impl ToSql for $t {
            fn to_sql(&self) -> Result<mysql::Value> {
                Ok(mysql::Value::Int(*self as i64))
            }
        }
    )*};
}
to_sql_int!(i8, i16, i32, i64, u8, u16, u32, isize);

impl ToSql for u64 {
    fn to_sql(&self) -> Result<mysql::Value> {
        i64::try_from(*self)
            .map(mysql::Value::Int)
            .map_err(|_| Error::Other(format!("u64 {self} is out of range for BIGINT")))
    }
}

impl ToSql for usize {
    fn to_sql(&self) -> Result<mysql::Value> {
        (*self as u64).to_sql()
    }
}

impl ToSql for bool {
    fn to_sql(&self) -> Result<mysql::Value> {
        Ok(mysql::Value::Int(*self as i64))
    }
}

impl ToSql for f32 {
    fn to_sql(&self) -> Result<mysql::Value> {
        Ok(mysql::Value::Double(*self as f64))
    }
}

impl ToSql for f64 {
    fn to_sql(&self) -> Result<mysql::Value> {
        Ok(mysql::Value::Double(*self))
    }
}

impl ToSql for str {
    fn to_sql(&self) -> Result<mysql::Value> {
        Ok(mysql::Value::Bytes(self.as_bytes().to_vec()))
    }
}

impl ToSql for String {
    fn to_sql(&self) -> Result<mysql::Value> {
        self.as_str().to_sql()
    }
}

impl ToSql for [u8] {
    fn to_sql(&self) -> Result<mysql::Value> {
        Ok(mysql::Value::Bytes(self.to_vec()))
    }
}

impl ToSql for Vec<u8> {
    fn to_sql(&self) -> Result<mysql::Value> {
        self.as_slice().to_sql()
    }
}

impl<const N: usize> ToSql for [u8; N] {
    fn to_sql(&self) -> Result<mysql::Value> {
        self.as_slice().to_sql()
    }
}

impl<T: ToSql> ToSql for Option<T> {
    fn to_sql(&self) -> Result<mysql::Value> {
        match self {
            Some(v) => v.to_sql(),
            None => Ok(mysql::Value::NULL),
        }
    }
}

impl<T: ToSql + ?Sized> ToSql for &T {
    fn to_sql(&self) -> Result<mysql::Value> {
        (**self).to_sql()
    }
}

impl<T: ToSql + ?Sized> ToSql for Box<T> {
    fn to_sql(&self) -> Result<mysql::Value> {
        (**self).to_sql()
    }
}

impl ToSql for mysql::Value {
    fn to_sql(&self) -> Result<mysql::Value> {
        Ok(self.clone())
    }
}

/// Statement parameters: none, positional (`?`, `?1`), or named (`:name`).
pub enum SqlParams {
    Empty,
    Positional(Vec<mysql::Value>),
    Named(Vec<(String, mysql::Value)>),
}

/// Anything that can be passed where rusqlite took `params`.
pub trait Params {
    fn into_params(self) -> Result<SqlParams>;
}

impl Params for SqlParams {
    fn into_params(self) -> Result<SqlParams> {
        Ok(self)
    }
}

impl Params for () {
    fn into_params(self) -> Result<SqlParams> {
        Ok(SqlParams::Empty)
    }
}

// Arrays get one impl per length, as in rusqlite, so that an empty `[]`
// has a single element type to infer (`&dyn ToSql`).
impl Params for [&dyn ToSql; 0] {
    fn into_params(self) -> Result<SqlParams> {
        Ok(SqlParams::Empty)
    }
}

macro_rules! array_params {
    ($($n:literal),*) => {$(
        impl<T: ToSql> Params for [T; $n] {
            fn into_params(self) -> Result<SqlParams> {
                positional(self.iter().map(|v| v as &dyn ToSql))
            }
        }
        impl<T: ToSql> Params for &[T; $n] {
            fn into_params(self) -> Result<SqlParams> {
                positional(self.iter().map(|v| v as &dyn ToSql))
            }
        }
    )*};
}
array_params!(
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24
);

impl Params for &[&dyn ToSql] {
    fn into_params(self) -> Result<SqlParams> {
        positional(self.iter().copied())
    }
}

impl Params for Vec<mysql::Value> {
    fn into_params(self) -> Result<SqlParams> {
        Ok(if self.is_empty() {
            SqlParams::Empty
        } else {
            SqlParams::Positional(self)
        })
    }
}

impl Params for &[(&str, &dyn ToSql)] {
    fn into_params(self) -> Result<SqlParams> {
        let mut out = Vec::with_capacity(self.len());
        for (k, v) in self {
            out.push((
                k.trim_start_matches([':', '@', '$']).to_string(),
                v.to_sql()?,
            ));
        }
        Ok(if out.is_empty() {
            SqlParams::Empty
        } else {
            SqlParams::Named(out)
        })
    }
}

impl<const N: usize> Params for &[(&str, &dyn ToSql); N] {
    fn into_params(self) -> Result<SqlParams> {
        self.as_slice().into_params()
    }
}

fn positional<'a>(it: impl Iterator<Item = &'a dyn ToSql>) -> Result<SqlParams> {
    let v = it.map(|p| p.to_sql()).collect::<Result<Vec<_>>>()?;
    Ok(if v.is_empty() {
        SqlParams::Empty
    } else {
        SqlParams::Positional(v)
    })
}

/// Positional parameters from an iterator (rusqlite's `params_from_iter`).
pub fn params_from_iter<I>(iter: I) -> Vec<mysql::Value>
where
    I: IntoIterator,
    I::Item: ToSql,
{
    iter.into_iter()
        .map(|v| v.to_sql().unwrap_or(mysql::Value::NULL))
        .collect()
}

/// Named parameters: `named_params! { ":id": id, ":name": name }`.
#[macro_export]
macro_rules! named_params {
    () => { &[] as &[(&str, &dyn $crate::sql::ToSql)] };
    ($($k:literal : $v:expr),+ $(,)?) => {
        &[$(($k, &$v as &dyn $crate::sql::ToSql)),+] as &[(&str, &dyn $crate::sql::ToSql)]
    };
}

/// Positional parameters: `params![a, b, c]`.
#[macro_export]
macro_rules! params {
    () => { &[] as &[&dyn $crate::sql::ToSql] };
    ($($v:expr),+ $(,)?) => {
        &[$(&$v as &dyn $crate::sql::ToSql),+] as &[&dyn $crate::sql::ToSql]
    };
}

pub use crate::{named_params, params};

// ---------------------------------------------------------------------------
// Values out

/// A Rust type a column can be read as.
pub trait FromSql: Sized {
    fn from_sql(v: &mysql::Value) -> std::result::Result<Self, String>;
}

fn as_i128(v: &mysql::Value) -> std::result::Result<i128, String> {
    match v {
        mysql::Value::Int(i) => Ok(*i as i128),
        mysql::Value::UInt(u) => Ok(*u as i128),
        // SUM() and AVG() come back as DECIMAL text; whole numbers read fine.
        mysql::Value::Bytes(b) => {
            let s = std::str::from_utf8(b).unwrap_or("").trim();
            s.parse::<i128>()
                .ok()
                .or_else(|| {
                    s.parse::<f64>()
                        .ok()
                        .filter(|f| f.fract() == 0.0)
                        .map(|f| f as i128)
                })
                .ok_or_else(|| format!("text {s:?} is not an integer"))
        }
        mysql::Value::NULL => Err("NULL read as a non-Option integer".into()),
        other => Err(format!("{other:?} is not an integer")),
    }
}

macro_rules! from_sql_int {
    ($($t:ty),*) => {$(
        impl FromSql for $t {
            fn from_sql(v: &mysql::Value) -> std::result::Result<Self, String> {
                let i = as_i128(v)?;
                <$t>::try_from(i).map_err(|_| format!("{i} is out of range for {}", stringify!($t)))
            }
        }
    )*};
}
from_sql_int!(i8, i16, i32, i64, u8, u16, u32, u64, usize, isize);

impl FromSql for bool {
    fn from_sql(v: &mysql::Value) -> std::result::Result<Self, String> {
        Ok(as_i128(v)? != 0)
    }
}

impl FromSql for f64 {
    fn from_sql(v: &mysql::Value) -> std::result::Result<Self, String> {
        match v {
            mysql::Value::Double(d) => Ok(*d),
            mysql::Value::Float(f) => Ok(*f as f64),
            mysql::Value::Int(i) => Ok(*i as f64),
            mysql::Value::UInt(u) => Ok(*u as f64),
            mysql::Value::Bytes(b) => std::str::from_utf8(b)
                .ok()
                .and_then(|s| s.trim().parse::<f64>().ok())
                .ok_or_else(|| format!("text {:?} is not a number", String::from_utf8_lossy(b))),
            mysql::Value::NULL => Err("NULL read as a non-Option number".into()),
            other => Err(format!("{other:?} is not a number")),
        }
    }
}

impl FromSql for f32 {
    fn from_sql(v: &mysql::Value) -> std::result::Result<Self, String> {
        f64::from_sql(v).map(|d| d as f32)
    }
}

impl FromSql for String {
    fn from_sql(v: &mysql::Value) -> std::result::Result<Self, String> {
        match v {
            mysql::Value::Bytes(b) => String::from_utf8(b.clone()).map_err(|e| e.to_string()),
            mysql::Value::Date(y, mo, d, h, mi, s, us) => Ok(if *us == 0 {
                format!("{y:04}-{mo:02}-{d:02} {h:02}:{mi:02}:{s:02}")
            } else {
                format!("{y:04}-{mo:02}-{d:02} {h:02}:{mi:02}:{s:02}.{us:06}")
            }),
            mysql::Value::NULL => Err("NULL read as a non-Option String".into()),
            other => Err(format!("{other:?} is not text")),
        }
    }
}

impl FromSql for Vec<u8> {
    fn from_sql(v: &mysql::Value) -> std::result::Result<Self, String> {
        match v {
            mysql::Value::Bytes(b) => Ok(b.clone()),
            mysql::Value::NULL => Err("NULL read as a non-Option blob".into()),
            other => Err(format!("{other:?} is not a blob")),
        }
    }
}

impl<T: FromSql> FromSql for Option<T> {
    fn from_sql(v: &mysql::Value) -> std::result::Result<Self, String> {
        match v {
            mysql::Value::NULL => Ok(None),
            other => T::from_sql(other).map(Some),
        }
    }
}

impl FromSql for mysql::Value {
    fn from_sql(v: &mysql::Value) -> std::result::Result<Self, String> {
        Ok(v.clone())
    }
}

/// A column position or a column name.
pub trait RowIndex {
    fn index(&self, row: &Row) -> Result<usize>;
}

impl RowIndex for usize {
    fn index(&self, row: &Row) -> Result<usize> {
        if *self < row.values.len() {
            Ok(*self)
        } else {
            Err(Error::InvalidColumnIndex(*self))
        }
    }
}

impl RowIndex for &str {
    fn index(&self, row: &Row) -> Result<usize> {
        row.columns
            .iter()
            .position(|c| c.eq_ignore_ascii_case(self))
            .ok_or_else(|| Error::InvalidColumnName(self.to_string()))
    }
}

impl RowIndex for String {
    fn index(&self, row: &Row) -> Result<usize> {
        self.as_str().index(row)
    }
}

impl RowIndex for &String {
    fn index(&self, row: &Row) -> Result<usize> {
        self.as_str().index(row)
    }
}

/// One result row.
pub struct Row {
    values: Vec<mysql::Value>,
    columns: Arc<[String]>,
}

impl Row {
    pub fn get<I: RowIndex, T: FromSql>(&self, idx: I) -> Result<T> {
        let i = idx.index(self)?;
        T::from_sql(&self.values[i]).map_err(|message| Error::Conversion {
            index: i,
            message: format!(
                "{} ({message})",
                self.columns.get(i).map_or("?", |c| c.as_str())
            ),
        })
    }

    pub fn get_unwrap<I: RowIndex, T: FromSql>(&self, idx: I) -> T {
        self.get(idx).expect("column read")
    }

    pub fn column_count(&self) -> usize {
        self.values.len()
    }

    pub fn column_name(&self, i: usize) -> Result<&str> {
        self.columns
            .get(i)
            .map(|s| s.as_str())
            .ok_or(Error::InvalidColumnIndex(i))
    }
}

/// `query_row(..).optional()`: no row becomes `None`.
pub trait OptionalExtension<T> {
    fn optional(self) -> Result<Option<T>>;
}

impl<T> OptionalExtension<T> for Result<T> {
    fn optional(self) -> Result<Option<T>> {
        match self {
            Ok(v) => Ok(Some(v)),
            Err(Error::QueryReturnedNoRows) => Ok(None),
            Err(e) => Err(e),
        }
    }
}

// ---------------------------------------------------------------------------
// SQL text

/// Rewrite SQLite's numbered `?1`, `?2` placeholders as plain `?`, putting
/// the values in the order the placeholders appear. Plain `?` is left alone.
fn number_placeholders(
    sql: &str,
    values: Vec<mysql::Value>,
) -> Result<(String, Vec<mysql::Value>)> {
    let bytes = sql.as_bytes();
    let mut out = String::with_capacity(sql.len());
    let mut order: Vec<usize> = Vec::new();
    let mut numbered = false;
    let mut i = 0;
    let mut quote: Option<u8> = None;
    while i < bytes.len() {
        let c = bytes[i];
        if let Some(q) = quote {
            out.push(c as char);
            if c == q {
                quote = None;
            }
            i += 1;
            continue;
        }
        match c {
            b'\'' | b'"' | b'`' => {
                quote = Some(c);
                out.push(c as char);
                i += 1;
            }
            b'-' if bytes.get(i + 1) == Some(&b'-') => {
                while i < bytes.len() && bytes[i] != b'\n' {
                    out.push(bytes[i] as char);
                    i += 1;
                }
            }
            b'?' => {
                let start = i + 1;
                let mut end = start;
                while end < bytes.len() && bytes[end].is_ascii_digit() {
                    end += 1;
                }
                if end > start {
                    numbered = true;
                    let n: usize = sql[start..end].parse().unwrap_or(0);
                    if n == 0 || n > values.len() {
                        return Err(Error::Other(format!("placeholder ?{n} has no value")));
                    }
                    order.push(n - 1);
                } else {
                    order.push(order.len());
                }
                out.push('?');
                i = end;
            }
            _ => {
                // keep multi-byte UTF-8 intact
                let ch = sql[i..].chars().next().unwrap_or('\0');
                out.push(ch);
                i += ch.len_utf8().max(1);
            }
        }
    }
    if !numbered {
        return Ok((sql.to_string(), values));
    }
    let reordered = order.into_iter().map(|k| values[k].clone()).collect();
    Ok((out, reordered))
}

fn to_mysql_params(sql: &str, p: SqlParams) -> Result<(String, mysql::Params)> {
    Ok(match p {
        SqlParams::Empty => (sql.to_string(), mysql::Params::Empty),
        SqlParams::Positional(v) => {
            let (sql, v) = number_placeholders(sql, v)?;
            (sql, mysql::Params::Positional(v))
        }
        SqlParams::Named(v) => {
            let map: HashMap<Vec<u8>, mysql::Value> = v
                .into_iter()
                .map(|(k, val)| (k.into_bytes(), val))
                .collect();
            (sql.to_string(), mysql::Params::Named(map))
        }
    })
}

// ---------------------------------------------------------------------------
// Connection on the worker thread

/// The connection a closure sent to [`Connection::call`] works with. Shaped
/// like `rusqlite::Connection`; its methods take `&self` so a prepared
/// statement and a direct `execute` can be used side by side.
pub struct Conn {
    inner: RefCell<mysql::Conn>,
    in_tx: RefCell<bool>,
}

impl Conn {
    fn new(inner: mysql::Conn) -> Self {
        Self {
            inner: RefCell::new(inner),
            in_tx: RefCell::new(false),
        }
    }

    fn run(&self, sql: &str, params: SqlParams) -> Result<(Vec<Row>, u64)> {
        let (sql, params) = to_mysql_params(sql, params)?;
        let mut conn = self.inner.borrow_mut();
        let mut result = conn.exec_iter(sql.as_str(), params)?;
        let mut rows = Vec::new();
        let mut affected = 0;
        while let Some(set) = result.iter() {
            affected += set.affected_rows();
            let columns: Arc<[String]> = set
                .columns()
                .as_ref()
                .iter()
                .map(|c| c.name_str().into_owned())
                .collect::<Vec<_>>()
                .into();
            for row in set {
                let row = row?;
                rows.push(Row {
                    values: row.unwrap(),
                    columns: columns.clone(),
                });
            }
        }
        Ok((rows, affected))
    }

    /// Run one statement; returns the number of rows it matched or wrote.
    pub fn execute<P: Params>(&self, sql: &str, params: P) -> Result<usize> {
        let (_, affected) = self.run(sql, params.into_params()?)?;
        Ok(affected as usize)
    }

    /// Run a script of `;`-separated statements with no parameters.
    pub fn execute_batch(&self, sql: &str) -> Result<()> {
        let mut conn = self.inner.borrow_mut();
        let mut result = conn.query_iter(sql)?;
        while let Some(set) = result.iter() {
            for row in set {
                row?;
            }
        }
        Ok(())
    }

    /// The first row of a query, mapped by `f`; no row is
    /// [`Error::QueryReturnedNoRows`].
    pub fn query_row<P, F, T>(&self, sql: &str, params: P, f: F) -> Result<T>
    where
        P: Params,
        F: FnOnce(&Row) -> Result<T>,
    {
        let (rows, _) = self.run(sql, params.into_params()?)?;
        match rows.first() {
            Some(r) => f(r),
            None => Err(Error::QueryReturnedNoRows),
        }
    }

    pub fn prepare(&self, sql: &str) -> Result<Statement<'_>> {
        Ok(Statement {
            conn: self,
            sql: sql.to_string(),
        })
    }

    pub fn prepare_cached(&self, sql: &str) -> Result<Statement<'_>> {
        self.prepare(sql)
    }

    /// The id MariaDB gave the last row inserted on this connection.
    pub fn last_insert_rowid(&self) -> i64 {
        self.inner.borrow().last_insert_id() as i64
    }

    /// Rows matched or written by the last statement.
    pub fn changes(&self) -> u64 {
        self.inner.borrow().affected_rows()
    }

    /// Start a transaction; it rolls back when dropped without `commit`.
    pub fn transaction(&mut self) -> Result<Transaction<'_>> {
        Transaction::begin(self)
    }

    /// The same as [`Conn::transaction`]; SQLite's lock modes don't apply.
    pub fn transaction_with_behavior(
        &mut self,
        _b: TransactionBehavior,
    ) -> Result<Transaction<'_>> {
        Transaction::begin(self)
    }

    /// Start a transaction through a shared reference (rusqlite's
    /// `unchecked_transaction`).
    pub fn unchecked_transaction(&self) -> Result<Transaction<'_>> {
        Transaction::begin(self)
    }
}

/// Kept so existing `transaction_with_behavior` calls compile.
#[derive(Debug, Clone, Copy)]
pub enum TransactionBehavior {
    Deferred,
    Immediate,
    Exclusive,
}

/// An open transaction. Derefs to [`Conn`]; rolls back on drop.
pub struct Transaction<'c> {
    conn: &'c Conn,
    done: bool,
    nested: bool,
}

impl<'c> Transaction<'c> {
    fn begin(conn: &'c Conn) -> Result<Self> {
        let nested = *conn.in_tx.borrow();
        if nested {
            conn.execute_batch("SAVEPOINT xiv_nested")?;
        } else {
            conn.execute_batch("START TRANSACTION")?;
            *conn.in_tx.borrow_mut() = true;
        }
        Ok(Self {
            conn,
            done: false,
            nested,
        })
    }

    pub fn commit(mut self) -> Result<()> {
        self.done = true;
        if self.nested {
            self.conn.execute_batch("RELEASE SAVEPOINT xiv_nested")
        } else {
            *self.conn.in_tx.borrow_mut() = false;
            self.conn.execute_batch("COMMIT")
        }
    }

    pub fn rollback(mut self) -> Result<()> {
        self.done = true;
        self.finish_rollback()
    }

    fn finish_rollback(&self) -> Result<()> {
        if self.nested {
            self.conn.execute_batch("ROLLBACK TO SAVEPOINT xiv_nested")
        } else {
            *self.conn.in_tx.borrow_mut() = false;
            self.conn.execute_batch("ROLLBACK")
        }
    }
}

impl Drop for Transaction<'_> {
    fn drop(&mut self) {
        if !self.done
            && let Err(e) = self.finish_rollback()
        {
            tracing::warn!(error = %e, "rolling back an abandoned transaction failed");
        }
    }
}

impl std::ops::Deref for Transaction<'_> {
    type Target = Conn;
    fn deref(&self) -> &Conn {
        self.conn
    }
}

/// A statement to run with different parameters (rusqlite's `Statement`).
pub struct Statement<'c> {
    conn: &'c Conn,
    sql: String,
}

impl Statement<'_> {
    pub fn execute<P: Params>(&mut self, params: P) -> Result<usize> {
        self.conn.execute(&self.sql, params)
    }

    /// Every row, each mapped by `f`. Rows are fetched up front.
    pub fn query_map<P, F, T>(&mut self, params: P, f: F) -> Result<MappedRows<F>>
    where
        P: Params,
        F: FnMut(&Row) -> Result<T>,
    {
        let (rows, _) = self.conn.run(&self.sql, params.into_params()?)?;
        Ok(MappedRows {
            rows: rows.into_iter(),
            f,
        })
    }

    /// Like `query_map` for closures that return another error type.
    pub fn query_and_then<P, F, T, E>(&mut self, params: P, f: F) -> Result<AndThenRows<F>>
    where
        P: Params,
        F: FnMut(&Row) -> std::result::Result<T, E>,
        E: From<Error>,
    {
        let (rows, _) = self.conn.run(&self.sql, params.into_params()?)?;
        Ok(AndThenRows {
            rows: rows.into_iter(),
            f,
        })
    }

    pub fn query_row<P, F, T>(&mut self, params: P, f: F) -> Result<T>
    where
        P: Params,
        F: FnOnce(&Row) -> Result<T>,
    {
        self.conn.query_row(&self.sql, params, f)
    }

    /// Every row, unmapped.
    pub fn query<P: Params>(&mut self, params: P) -> Result<Rows> {
        let (rows, _) = self.conn.run(&self.sql, params.into_params()?)?;
        Ok(Rows {
            rows: rows.into_iter(),
            current: None,
        })
    }

    pub fn exists<P: Params>(&mut self, params: P) -> Result<bool> {
        let (rows, _) = self.conn.run(&self.sql, params.into_params()?)?;
        Ok(!rows.is_empty())
    }
}

pub struct MappedRows<F> {
    rows: std::vec::IntoIter<Row>,
    f: F,
}

impl<F, T> Iterator for MappedRows<F>
where
    F: FnMut(&Row) -> Result<T>,
{
    type Item = Result<T>;
    fn next(&mut self) -> Option<Self::Item> {
        self.rows.next().map(|r| (self.f)(&r))
    }
}

pub struct AndThenRows<F> {
    rows: std::vec::IntoIter<Row>,
    f: F,
}

impl<F, T, E> Iterator for AndThenRows<F>
where
    F: FnMut(&Row) -> std::result::Result<T, E>,
{
    type Item = std::result::Result<T, E>;
    fn next(&mut self) -> Option<Self::Item> {
        self.rows.next().map(|r| (self.f)(&r))
    }
}

/// Unmapped rows, read with `while let Some(r) = rows.next()?`.
pub struct Rows {
    rows: std::vec::IntoIter<Row>,
    current: Option<Row>,
}

impl Rows {
    #[allow(clippy::should_implement_trait)]
    pub fn next(&mut self) -> Result<Option<&Row>> {
        self.current = self.rows.next();
        Ok(self.current.as_ref())
    }
}

// ---------------------------------------------------------------------------
// The async handle

type Job = Box<dyn FnOnce(&mut Conn) + Send>;

/// Tells the test pool a connection's worker has stopped (see `test_db`).
struct CloseNote(String);

impl Drop for CloseNote {
    fn drop(&mut self) {
        crate::test_db::note_close(&self.0);
    }
}

/// A handle to one MariaDB connection on its own worker thread. Cheap to
/// clone; clones share the worker, so their closures run in the order sent.
#[derive(Clone)]
pub struct Connection {
    tx: mpsc::Sender<Job>,
    url: Arc<str>,
}

impl std::fmt::Debug for Connection {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("Connection")
            .field("database", &database_name(&self.url))
            .finish()
    }
}

/// The database name at the end of a `mysql://` URL.
pub fn database_name(url: &str) -> String {
    url.rsplit('/')
        .next()
        .unwrap_or("")
        .split('?')
        .next()
        .unwrap_or("")
        .to_string()
}

fn connect(url: &str) -> Result<mysql::Conn> {
    let opts =
        mysql::Opts::from_url(url).map_err(|e| Error::Other(format!("database url: {e}")))?;
    let builder = mysql::OptsBuilder::from_opts(opts)
        .additional_capabilities(mysql::consts::CapabilityFlags::CLIENT_FOUND_ROWS)
        .stmt_cache_size(Some(512))
        .tcp_connect_timeout(Some(Duration::from_secs(10)))
        .init(vec![
            format!("SET SESSION sql_mode = '{SQL_MODE}'"),
            "SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci".to_string(),
            "SET SESSION time_zone = '+00:00'".to_string(),
        ]);
    Ok(mysql::Conn::new(builder)?)
}

impl Connection {
    /// Connect to the database at `url` (`mysql://user:pass@host:port/db`).
    pub async fn open(url: &str) -> Result<Self> {
        let url: Arc<str> = Arc::from(url);
        let (tx, rx) = mpsc::channel::<Job>();
        let (ready_tx, ready_rx) = tokio::sync::oneshot::channel::<Result<()>>();
        let worker_url = url.clone();
        std::thread::Builder::new()
            .name(format!("db-{}", database_name(&url)))
            .spawn(move || {
                let db = database_name(&worker_url);
                crate::test_db::note_open(&db);
                let _closed = CloseNote(db);
                let mut conn = match connect(&worker_url) {
                    Ok(c) => {
                        let _ = ready_tx.send(Ok(()));
                        Conn::new(c)
                    }
                    Err(e) => {
                        let _ = ready_tx.send(Err(e));
                        return;
                    }
                };
                while let Ok(job) = rx.recv() {
                    // A dropped connection (server restart, idle timeout) is
                    // reopened before the next job runs.
                    if conn.inner.get_mut().ping().is_err() {
                        match connect(&worker_url) {
                            Ok(c) => conn = Conn::new(c),
                            Err(e) => tracing::error!(error = %e, "database reconnect failed"),
                        }
                    }
                    job(&mut conn);
                }
            })
            .map_err(|e| Error::Other(format!("starting database thread: {e}")))?;
        ready_rx
            .await
            .map_err(|_| Error::Other("database thread exited".into()))??;
        Ok(Self { tx, url })
    }

    /// Run `f` on the worker's connection and wait for its result.
    pub async fn call<F, R>(&self, f: F) -> Result<R>
    where
        F: FnOnce(&mut Conn) -> Result<R> + Send + 'static,
        R: Send + 'static,
    {
        let (done_tx, done_rx) = tokio::sync::oneshot::channel();
        self.tx
            .send(Box::new(move |c: &mut Conn| {
                let _ = done_tx.send(f(c));
            }))
            .map_err(|_| Error::Other("database thread is gone".into()))?;
        done_rx
            .await
            .map_err(|_| Error::Other("database job was dropped".into()))?
    }

    /// The URL this connection was opened with (passwords included; don't log it).
    pub fn url(&self) -> &str {
        &self.url
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn numbered_placeholders_become_plain_in_order() {
        let (sql, v) = number_placeholders(
            "SELECT ?2, '?1', ?1 -- ?3\n",
            vec![mysql::Value::Int(1), mysql::Value::Int(2)],
        )
        .unwrap();
        assert_eq!(sql, "SELECT ?, '?1', ? -- ?3\n");
        assert_eq!(v, vec![mysql::Value::Int(2), mysql::Value::Int(1)]);
    }

    #[test]
    fn plain_placeholders_are_untouched() {
        let (sql, v) = number_placeholders(
            "SELECT ?, ?",
            vec![mysql::Value::Int(1), mysql::Value::Int(2)],
        )
        .unwrap();
        assert_eq!(sql, "SELECT ?, ?");
        assert_eq!(v.len(), 2);
    }

    #[test]
    fn integers_read_with_range_checks() {
        assert_eq!(u8::from_sql(&mysql::Value::Int(200)).unwrap(), 200);
        assert!(u8::from_sql(&mysql::Value::Int(300)).is_err());
        assert!(u32::from_sql(&mysql::Value::Int(-1)).is_err());
        assert_eq!(
            i64::from_sql(&mysql::Value::Bytes(b"42".to_vec())).unwrap(),
            42
        );
        assert_eq!(
            i64::from_sql(&mysql::Value::Bytes(b"42.000".to_vec())).unwrap(),
            42
        );
        assert!(i64::from_sql(&mysql::Value::NULL).is_err());
        assert_eq!(Option::<i64>::from_sql(&mysql::Value::NULL).unwrap(), None);
    }
}
