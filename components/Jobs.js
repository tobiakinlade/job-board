import Job from './Job';

export default function Jobs({ jobs }) {
  return (
    <>
      {jobs.map((job, index) => (
        <Job key={index} job={job} />
      ))}
    </>
  );
}
