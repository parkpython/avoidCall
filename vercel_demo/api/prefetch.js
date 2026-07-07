export default function handler(req, res) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return res.status(405).json({ message: 'Method not allowed' });
  }

  const body = typeof req.body === 'object' && req.body !== null ? req.body : {};
  const language = body.language || 'English';
  const text = body.text || '';

  return res.status(200).json({
    status: 'success',
    translated_text: `[demo ${language}] ${text}`,
  });
}
