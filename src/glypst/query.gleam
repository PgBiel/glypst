/// Format of the string returned by a query operation.
pub type QueryFormat {
  /// The query result is returned as a JSON string.
  Json
  /// The query result is returned as a YAML string.
  Yaml
}

/// Additional query options.
pub type QueryOption {
  /// Return just this particular field of the element(s) matched in the query.
  Field(String)
  /// Set the format of the string returned by the query.
  /// When unspecified, it defaults to JSON.
  Format(QueryFormat)
  /// Exactly one element should be matched by the query (which, thus, won't
  /// return a list, just the matched element directly), otherwise error.
  One
}
