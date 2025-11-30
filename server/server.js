const express = require('express');
const multer = require('multer');
const pdf = require('pdf-parse');
const cors = require('cors');

const app = express();
app.use(cors());

const upload = multer({ storage: multer.memoryStorage() });

// POST /extract - accepts a file field named 'file' (PDF). Returns { text: '...', fields: { possible parsed fields } }
app.post('/extract', upload.single('file'), async (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'No file uploaded' });
  try {
    const dataBuffer = req.file.buffer;
    const data = await pdf(dataBuffer);
    const text = data.text || '';

    // Very simple heuristics to extract typical invoice fields (amounts, IBAN-like strings, emails)
    const emails = Array.from(new Set((text.match(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/ig) || []).map(s => s.trim())));
    const amounts = Array.from(new Set((text.match(/\b\d{1,3}(?:[\,\.]\d{3})*(?:[\,\.]\d{2})\b/g) || []).map(s => s.replace(/,/g, '.'))));
    const ibans = Array.from(new Set((text.match(/\b[A-Z]{2}[0-9A-Z]{10,}\b/ig) || []).map(s => s.trim())));

    // Return extracted values and raw text for client-side parsing.
    return res.json({ text, emails, amounts, ibans });
  } catch (err) {
    console.error('PDF parse error', err);
    return res.status(500).json({ error: 'Failed to parse PDF' });
  }
});

const port = process.env.PORT || 8080;
app.listen(port, () => console.log(`ShieldPay extractor listening on port ${port}`));
