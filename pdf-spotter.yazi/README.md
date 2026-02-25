# pdf-spotter.yazi

A spotter for PDF files, providing metadata such as title, author, and page count.

## Usage

In your `yazi.toml`, add the following configuration to enable the PDF spotter:

```toml
prepend_spotters = [{ mime = "application/pdf", run = "pdf-spotter" }]
```
