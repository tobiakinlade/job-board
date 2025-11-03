import React, { useState, useEffect } from 'react';

const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:3001';

function App() {
  const [jobs, setJobs] = useState([]);
  const [selectedJob, setSelectedJob] = useState(null);
  const [showJobForm, setShowJobForm] = useState(false);
  const [showApplicationForm, setShowApplicationForm] = useState(false);
  const [loading, setLoading] = useState(true);

  const [jobForm, setJobForm] = useState({
    title: '',
    company: '',
    location: '',
    description: '',
    salary_range: '',
    job_type: 'Full-time'
  });

  const [applicationForm, setApplicationForm] = useState({
    applicant_name: '',
    applicant_email: '',
    resume_url: '',
    cover_letter: ''
  });

  useEffect(() => {
    fetchJobs();
  }, []);

  const fetchJobs = async () => {
    try {
      const response = await fetch(`${API_URL}/jobs`);
      const data = await response.json();
      setJobs(data);
      setLoading(false);
    } catch (error) {
      console.error('Error fetching jobs:', error);
      setLoading(false);
    }
  };

  const handleJobSubmit = async (e) => {
    e.preventDefault();
    try {
      const response = await fetch(`${API_URL}/jobs`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(jobForm),
      });
      if (response.ok) {
        fetchJobs();
        setShowJobForm(false);
        setJobForm({
          title: '',
          company: '',
          location: '',
          description: '',
          salary_range: '',
          job_type: 'Full-time'
        });
      }
    } catch (error) {
      console.error('Error creating job:', error);
    }
  };

  const handleApplicationSubmit = async (e) => {
    e.preventDefault();
    try {
      const response = await fetch(`${API_URL}/applications`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          ...applicationForm,
          job_id: selectedJob.id
        }),
      });
      if (response.ok) {
        alert('Application submitted successfully!');
        setShowApplicationForm(false);
        setApplicationForm({
          applicant_name: '',
          applicant_email: '',
          resume_url: '',
          cover_letter: ''
        });
      }
    } catch (error) {
      console.error('Error submitting application:', error);
    }
  };

  const styles = {
    container: {
      maxWidth: '1200px',
      margin: '0 auto',
      padding: '20px',
    },
    header: {
      backgroundColor: '#2c3e50',
      color: 'white',
      padding: '30px 20px',
      marginBottom: '30px',
      borderRadius: '8px',
      textAlign: 'center',
    },
    title: {
      fontSize: '2.5em',
      marginBottom: '10px',
    },
    buttonPrimary: {
      backgroundColor: '#3498db',
      color: 'white',
      border: 'none',
      padding: '12px 24px',
      borderRadius: '5px',
      cursor: 'pointer',
      fontSize: '16px',
      marginTop: '10px',
    },
    jobGrid: {
      display: 'grid',
      gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))',
      gap: '20px',
      marginBottom: '30px',
    },
    jobCard: {
      backgroundColor: 'white',
      padding: '20px',
      borderRadius: '8px',
      boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
      cursor: 'pointer',
      transition: 'transform 0.2s',
    },
    jobTitle: {
      fontSize: '1.5em',
      marginBottom: '10px',
      color: '#2c3e50',
    },
    jobCompany: {
      fontSize: '1.1em',
      color: '#7f8c8d',
      marginBottom: '10px',
    },
    jobDetails: {
      fontSize: '0.9em',
      color: '#95a5a6',
      marginBottom: '5px',
    },
    modal: {
      position: 'fixed',
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      backgroundColor: 'rgba(0,0,0,0.5)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      zIndex: 1000,
    },
    modalContent: {
      backgroundColor: 'white',
      padding: '30px',
      borderRadius: '8px',
      maxWidth: '600px',
      maxHeight: '80vh',
      overflow: 'auto',
      width: '90%',
    },
    form: {
      display: 'flex',
      flexDirection: 'column',
      gap: '15px',
    },
    input: {
      padding: '10px',
      borderRadius: '5px',
      border: '1px solid #ddd',
      fontSize: '16px',
    },
    textarea: {
      padding: '10px',
      borderRadius: '5px',
      border: '1px solid #ddd',
      fontSize: '16px',
      minHeight: '100px',
      resize: 'vertical',
    },
    buttonSecondary: {
      backgroundColor: '#95a5a6',
      color: 'white',
      border: 'none',
      padding: '12px 24px',
      borderRadius: '5px',
      cursor: 'pointer',
      fontSize: '16px',
      marginLeft: '10px',
    },
    buttonSuccess: {
      backgroundColor: '#27ae60',
      color: 'white',
      border: 'none',
      padding: '12px 24px',
      borderRadius: '5px',
      cursor: 'pointer',
      fontSize: '16px',
      marginTop: '10px',
    },
  };

  if (loading) {
    return <div style={styles.container}>Loading...</div>;
  }

  return (
    <div style={styles.container}>
      <header style={styles.header}>
        <h1 style={styles.title}>Job Board</h1>
        <p>Find your dream job today</p>
        <button style={styles.buttonPrimary} onClick={() => setShowJobForm(true)}>
          Post a Job
        </button>
      </header>

      <div style={styles.jobGrid}>
        {jobs.map(job => (
          <div
            key={job.id}
            style={styles.jobCard}
            onClick={() => setSelectedJob(job)}
            onMouseEnter={(e) => e.currentTarget.style.transform = 'translateY(-5px)'}
            onMouseLeave={(e) => e.currentTarget.style.transform = 'translateY(0)'}
          >
            <h2 style={styles.jobTitle}>{job.title}</h2>
            <p style={styles.jobCompany}>{job.company}</p>
            <p style={styles.jobDetails}>📍 {job.location}</p>
            <p style={styles.jobDetails}>💼 {job.job_type}</p>
            {job.salary_range && (
              <p style={styles.jobDetails}>💰 {job.salary_range}</p>
            )}
          </div>
        ))}
      </div>

      {/* Job Detail Modal */}
      {selectedJob && (
        <div style={styles.modal} onClick={() => setSelectedJob(null)}>
          <div style={styles.modalContent} onClick={(e) => e.stopPropagation()}>
            <h2>{selectedJob.title}</h2>
            <h3>{selectedJob.company}</h3>
            <p><strong>Location:</strong> {selectedJob.location}</p>
            <p><strong>Type:</strong> {selectedJob.job_type}</p>
            {selectedJob.salary_range && (
              <p><strong>Salary:</strong> {selectedJob.salary_range}</p>
            )}
            <p style={{ marginTop: '20px' }}>{selectedJob.description}</p>
            <div style={{ marginTop: '20px' }}>
              <button style={styles.buttonSuccess} onClick={() => {
                setShowApplicationForm(true);
                setSelectedJob(selectedJob);
              }}>
                Apply Now
              </button>
              <button style={styles.buttonSecondary} onClick={() => setSelectedJob(null)}>
                Close
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Job Form Modal */}
      {showJobForm && (
        <div style={styles.modal} onClick={() => setShowJobForm(false)}>
          <div style={styles.modalContent} onClick={(e) => e.stopPropagation()}>
            <h2>Post a New Job</h2>
            <form style={styles.form} onSubmit={handleJobSubmit}>
              <input
                style={styles.input}
                type="text"
                placeholder="Job Title"
                value={jobForm.title}
                onChange={(e) => setJobForm({...jobForm, title: e.target.value})}
                required
              />
              <input
                style={styles.input}
                type="text"
                placeholder="Company"
                value={jobForm.company}
                onChange={(e) => setJobForm({...jobForm, company: e.target.value})}
                required
              />
              <input
                style={styles.input}
                type="text"
                placeholder="Location"
                value={jobForm.location}
                onChange={(e) => setJobForm({...jobForm, location: e.target.value})}
                required
              />
              <textarea
                style={styles.textarea}
                placeholder="Job Description"
                value={jobForm.description}
                onChange={(e) => setJobForm({...jobForm, description: e.target.value})}
                required
              />
              <input
                style={styles.input}
                type="text"
                placeholder="Salary Range (e.g., $80k - $120k)"
                value={jobForm.salary_range}
                onChange={(e) => setJobForm({...jobForm, salary_range: e.target.value})}
              />
              <select
                style={styles.input}
                value={jobForm.job_type}
                onChange={(e) => setJobForm({...jobForm, job_type: e.target.value})}
              >
                <option value="Full-time">Full-time</option>
                <option value="Part-time">Part-time</option>
                <option value="Contract">Contract</option>
                <option value="Internship">Internship</option>
              </select>
              <div>
                <button style={styles.buttonPrimary} type="submit">
                  Post Job
                </button>
                <button style={styles.buttonSecondary} type="button" onClick={() => setShowJobForm(false)}>
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Application Form Modal */}
      {showApplicationForm && (
        <div style={styles.modal} onClick={() => setShowApplicationForm(false)}>
          <div style={styles.modalContent} onClick={(e) => e.stopPropagation()}>
            <h2>Apply for {selectedJob?.title}</h2>
            <form style={styles.form} onSubmit={handleApplicationSubmit}>
              <input
                style={styles.input}
                type="text"
                placeholder="Your Name"
                value={applicationForm.applicant_name}
                onChange={(e) => setApplicationForm({...applicationForm, applicant_name: e.target.value})}
                required
              />
              <input
                style={styles.input}
                type="email"
                placeholder="Email Address"
                value={applicationForm.applicant_email}
                onChange={(e) => setApplicationForm({...applicationForm, applicant_email: e.target.value})}
                required
              />
              <input
                style={styles.input}
                type="url"
                placeholder="Resume URL (optional)"
                value={applicationForm.resume_url}
                onChange={(e) => setApplicationForm({...applicationForm, resume_url: e.target.value})}
              />
              <textarea
                style={styles.textarea}
                placeholder="Cover Letter"
                value={applicationForm.cover_letter}
                onChange={(e) => setApplicationForm({...applicationForm, cover_letter: e.target.value})}
              />
              <div>
                <button style={styles.buttonSuccess} type="submit">
                  Submit Application
                </button>
                <button style={styles.buttonSecondary} type="button" onClick={() => setShowApplicationForm(false)}>
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

export default App;
