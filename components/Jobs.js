import Job from './Job';

export default function Jobs({ jobs, isDashboard }) {
  return (
    <>
      {jobs.map((job, index) => (
        <Job key={index} job={job} isDashboard={isDashboard} />
      ))}
    </>
  );
}
