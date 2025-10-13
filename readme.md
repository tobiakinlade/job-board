Job Board Application
A full-stack job board application with React frontend, Node.js/Express backend, and PostgreSQL database.
Project Structure
job-board/
├── docker-compose.yml
├── backend/
│   ├── Dockerfile
│   ├── package.json
│   ├── server.js
│   └── init.sql
└── frontend/
    ├── Dockerfile
    ├── package.json
    ├── public/
    │   └── index.html
    └── src/
        ├── App.js
        ├── index.js
        └── index.css
Setup Instructions
1. Create the Project Structure
Create the directories:
bashmkdir -p job-board/backend job-board/frontend/public job-board/frontend/src
cd job-board
2. Copy All Files
Copy each file from the artifacts into their respective locations:

docker-compose.yml → root directory
backend/Dockerfile → backend directory
backend/package.json → backend directory
backend/server.js → backend directory
backend/init.sql → backend directory
frontend/Dockerfile → frontend directory
frontend/package.json → frontend directory
frontend/public/index.html → frontend/public directory
frontend/src/index.js → frontend/src directory
frontend/src/index.css → frontend/src directory
frontend/src/App.js → frontend/src directory

3. Start the Application
From the job-board directory, run:
bashdocker-compose up --build
This will:

Build the frontend and backend Docker images
Pull the PostgreSQL image
Create and start all containers
Initialize the database with sample data

4. Access the Application

Frontend: http://localhost:3000
Backend API: http://localhost:3001
Database: localhost:5432

Features

✅ View all job listings
✅ View detailed job information
✅ Post new job listings
✅ Apply to jobs
✅ Responsive design
✅ Full CRUD operations via REST API

API Endpoints
MethodEndpointDescriptionGET/api/jobsGet all jobsGET/api/jobs/:idGet single jobPOST/api/jobsCreate new jobPUT/api/jobs/:idUpdate jobDELETE/api/jobs/:idDelete jobPOST/api/applicationsSubmit applicationGET/api/jobs/:id/applicationsGet applications for a job
Database Schema
Jobs Table

id (SERIAL PRIMARY KEY)
title (VARCHAR)
company (VARCHAR)
location (VARCHAR)
description (TEXT)
salary_range (VARCHAR)
job_type (VARCHAR)
posted_date (TIMESTAMP)
created_at (TIMESTAMP)

Applications Table

id (SERIAL PRIMARY KEY)
job_id (INTEGER, foreign key)
applicant_name (VARCHAR)
applicant_email (VARCHAR)
resume_url (VARCHAR)
cover_letter (TEXT)
applied_at (TIMESTAMP)

Development
Running Without Docker
Backend:
bashcd backend
npm install
# Set environment variables
export DB_HOST=localhost
export DB_USER=jobboard
export DB_PASSWORD=jobboard123
export DB_NAME=jobboard
npm start
Frontend:
bashcd frontend
npm install
npm start
Stopping the Application
bashdocker-compose down
Removing All Data
bashdocker-compose down -v
Technologies Used

Frontend: React, JavaScript
Backend: Node.js, Express.js
Database: PostgreSQL
Containerization: Docker, Docker Compose

Environment Variables
Backend

DB_HOST - Database host (default: localhost)
DB_USER - Database user (default: jobboard)
DB_PASSWORD - Database password (default: jobboard123)
DB_NAME - Database name (default: jobboard)
DB_PORT - Database port (default: 5432)
PORT - Backend port (default: 3001)

Frontend

REACT_APP_API_URL - Backend API URL (default: http://localhost:3001)

Troubleshooting
Containers won't start:

Make sure Docker is running
Check if ports 3000, 3001, or 5432 are already in use
Run docker-compose logs to see error messages

Database connection errors:

Wait a few seconds for the database to initialize
Check the healthcheck status with docker-compose ps

Frontend can't connect to backend:

Verify the backend is running on port 3001
Check CORS settings in backend/server.js
