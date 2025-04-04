pub type Span {
  Span(start: #(Int, Int), end: #(Int, Int), file_path: String)
}

pub fn empty() -> Span {
  Span(start: #(0, 0), end: #(0, 0), file_path: "")
}
