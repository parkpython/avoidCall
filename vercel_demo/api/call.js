export default function handler(req, res) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return res.status(405).json({ message: 'Method not allowed' });
  }

  return res.status(200).json({
    status: 'success',
    call_id: 'test_mode',
    mode: 'vercel_demo',
    message: 'Demo call started.',
  });
}
