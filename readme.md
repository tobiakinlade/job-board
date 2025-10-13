# 🧑‍💼 Job Board Application 

A **full-stack Job Board application** deployed on **Kubernetes**, featuring a **React** frontend, **Node.js/Express** backend, and **PostgreSQL** database.  
This project demonstrates **container orchestration**, **service networking**, **persistent storage**, and **environment management** using Kubernetes.

---

## 🧠 Overview

The application allows users to:
- Browse job listings  
- View job details  
- Post new job openings  
- Apply to jobs  
- Manage data through a RESTful API  

---

## 🏗️ Architecture

                   ┌──────────────────────────────┐
                   │        Frontend (React)      │
                   │  Deployment + Service (Node) │
                   │        Port: 3000            │
                   └──────────────┬───────────────┘
                                  │
                   ┌──────────────┴───────────────┐
                   │      Backend API (Express)   │
                   │  Deployment + Service (Node) │
                   │        Port: 3001            │
                   └──────────────┬───────────────┘
                                  │
                   ┌──────────────┴───────────────┐
                   │       PostgreSQL Database    │
                   │  StatefulSet + PVC + Service │
                   │        Port: 5432            │
                   └──────────────────────────────┘

---

## 📁 Project Structure

job-board/
├── backend/
│ ├── Dockerfile
│ ├── package.json
│ ├── server.js
│ └── init.sql
├── frontend/
│ ├── Dockerfile
│ ├── package.json
│ ├── public/
│ │ └── index.html
│ └── src/
│ ├── App.js
│ ├── index.js
│ └── index.css
├── k8s/
│ ├── backend-deployment.yaml
│ ├── backend-service.yaml
│ ├── frontend-deployment.yaml
│ ├── frontend-service.yaml
│ ├── postgres-statefulset.yaml
│ ├── postgres-service.yaml
│ └── configmap.yaml
└── docker-compose.yml # Optional for local testing


---

