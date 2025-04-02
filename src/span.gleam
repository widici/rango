pub type Span {
  Span(start: Int, end: Int, file_path: String)
}

pub fn empty() -> Span {
  Span(start: 0, end: 0, file_path: "")
}
