import Link from 'next/link';
import React from 'react';

export default function Job({ job, isDashboard }) {
  return (
    <div className='mb-4 mt-20 pl-16 pr-16'>
      <Link href={`/job/${job.id}`}>
        <a className='text-xl font-bold underline'>{job.title}</a>
      </Link>

      <h2 className='text-base font-normal mt-3'>{job.description}</h2>
      <div className='mt-4'>
        {isDashboard && job.published && (
          <span className='bg-black text-white uppercase text-sm p-2 mr-5'>
            ✅ Published
          </span>
        )}
        {isDashboard && !job.published && (
          <span className='bg-black text-white uppercase text-sm p-2 mr-5'>
            ❌ Unpublished
          </span>
        )}
        <h4 className='inline'>Posted by</h4>
        <div className='ml-3 -mt-6 inline'>
          <span>
            <p>
              <span className='text-baase font-medium color-primary underline'>
                {job.author.name}
              </span>
            </p>
          </span>
        </div>
      </div>
    </div>
  );
}
