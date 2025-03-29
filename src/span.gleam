pub type Span {
  Span(start: Int, end: Int)
}

pub fn empty() -> Span {
  Span(start: 0, end: 0)
}
