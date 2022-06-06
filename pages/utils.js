export default function Utils() {
  const cleanDB = async () => {
    await fetch('/api/utils', {
      body: JSON.stringify({
        task: 'clean_database',
      }),
      headers: {
        'Content-Type': 'application/json',
      },
      method: 'POST',
    });
  };

  const generateUsersAndJobs = async () => {
    await fetch('/api/utils', {
      body: JSON.stringify({
        task: 'generate_users_and_jobs',
      }),
      headers: {
        'Content-Type': 'application/json',
      },
      method: 'POST',
    });
  };

  const generateNewJob = async () => {
    await fetch('/api/utils', {
      body: JSON.stringify({
        task: 'generate_one_job',
      }),
      headers: {
        'Content-Type': 'application/json',
      },
      method: 'POST',
    });
  };
  return (
    <div className='mt-10 ml-20'>
      <h2 className='mb-10 text-xl'>Utils</h2>
      <div className='flex-1 mb-5'>
        <button
          onClick={cleanDB}
          className='border px-8 py-2 mt-5 mr-8 font-bold rounded-full color-accent-contrast bg-color-acccent hover:bg-color-accent-hover-darker'
        >
          Clean database
        </button>
      </div>

      <div className='flex-1 mb-5'>
        <button
          onClick={generateUsersAndJobs}
          className='border px-8 py-2 mt-5 mr-8 font-bold rounded-full color-accent-contrast bg-color-acccent hover:bg-color-accent-hover-darker'
        >
          Generate 10 users and some jobs
        </button>
      </div>

      <div className='flex-1 mb-5'>
        <button
          onClick={generateNewJob}
          className='border px-8 py-2 mt-5 mr-8 font-bold rounded-full color-accent-contrast bg-color-acccent hover:bg-color-accent-hover-darker'
        >
          Generate 1 new job
        </button>
      </div>
    </div>
  );
}
