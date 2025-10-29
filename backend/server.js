const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const { Pool } = require('pg');

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(cors());
app.use(bodyParser.json());

// Health check endpoints for ALB
app.get('/', (req, res) => {
  res.status(200).json({ status: 'healthy', service: 'job-board-backend' });
});

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy', service: 'job-board-backend' });
});

// Database connection
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'jobboard',
  password: process.env.DB_PASSWORD || 'jobboard123',
  database: process.env.DB_NAME || 'jobboard',
  port: process.env.DB_PORT || 5432,
});

// Test database connection
pool.connect((err, client, release) => {
  if (err) {
    console.error('Error connecting to the database:', err.stack);
  } else {
    console.log('Connected to PostgreSQL database');
    release();
  }
});

// Routes

// Get all jobs
app.get('/api/jobs', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM jobs ORDER BY posted_date DESC');
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get single job
app.get('/api/jobs/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query('SELECT * FROM jobs WHERE id = $1', [id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Job not found' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create new job
app.post('/api/jobs', async (req, res) => {
  try {
    const { title, company, location, description, salary_range, job_type } = req.body;
    const result = await pool.query(
      'INSERT INTO jobs (title, company, location, description, salary_range, job_type) VALUES ($1, $2, $3, $4, $5, $6) RETURNING *',
      [title, company, location, description, salary_range, job_type]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update job
app.put('/api/jobs/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { title, company, location, description, salary_range, job_type } = req.body;
    const result = await pool.query(
      'UPDATE jobs SET title=$1, company=$2, location=$3, description=$4, salary_range=$5, job_type=$6 WHERE id=$7 RETURNING *',
      [title, company, location, description, salary_range, job_type, id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Job not found' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Delete job
app.delete('/api/jobs/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query('DELETE FROM jobs WHERE id = $1 RETURNING *', [id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Job not found' });
    }
    res.json({ message: 'Job deleted successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Submit application
app.post('/api/applications', async (req, res) => {
  try {
    const { job_id, applicant_name, applicant_email, resume_url, cover_letter } = req.body;
    const result = await pool.query(
      'INSERT INTO applications (job_id, applicant_name, applicant_email, resume_url, cover_letter) VALUES ($1, $2, $3, $4, $5) RETURNING *',
      [job_id, applicant_name, applicant_email, resume_url, cover_letter]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get applications for a job
app.get('/api/jobs/:id/applications', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query('SELECT * FROM applications WHERE job_id = $1 ORDER BY applied_at DESC', [id]);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
