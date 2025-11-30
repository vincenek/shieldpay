# ShieldPay PDF Extractor (demo)

This is a small Node.js microservice used by the ShieldPay Flutter app to extract text and simple fields from invoice PDFs.

Requirements
- Node 16+ (or compatible)

Install and run locally:

```powershell
cd server
npm install
npm start
```

The service exposes:
- POST `/extract` - multipart/form-data, file field name `file` (PDF). Returns JSON `{ text, emails, amounts, ibans }`.

Deployment
- Deploy as a small web service (Heroku, Railway, Fly, GCP Cloud Run). Make sure to set CORS appropriately and secure the endpoint behind authentication if you use it in production.

Notes
- This demo uses `pdf-parse` to extract text and some simple regex-based heuristics. For production, consider adding more robust OCR (Tesseract) or pdf.js parsing, and rate-limiting/authentication.
