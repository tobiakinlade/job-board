import Jobs from 'components/Jobs';
import { getJobs, getUser } from 'lib/data';
import prisma from 'lib/prisma';
import { getSession, useSession } from 'next-auth/react';
import Head from 'next/head';
import Image from 'next/image';
import Link from 'next/link';
import { useRouter } from 'next/router';

export default function Home({ jobs, user }) {
  const { data: session, status } = useSession();
  const router = useRouter();
  if (session && !session.user.name) {
    router.push('/setup');
  }

  return (
    <div>
      <Head>
        <title>Job Board</title>
      </Head>
      <div className='mt-10'>
        <div className='text-center p-4 m-4'>
          <h2 className='mb-10 text-4xl font-bold'>Find a job!</h2>
        </div>
        {!session && <a href='/api/auth/signin'>Login</a>}
        <Jobs jobs={jobs} />
        {session && (
          <>
            <p className='mb-10 text-2xl font-normal'>
              Welcome, {user.name}
              {user.company && (
                <span className='bg-black text-white uppercase text-sm p-2'>
                  Company
                </span>
              )}
            </p>
            {user.company ? (
              <>
                <Link href={`/new`}>
                  <button className='border px-8 py-2 mt-5 font-bold rounded-full bg-black text-white border-black'>
                    click here to post a new job
                  </button>
                </Link>

                <Link href={`/dashboard`}>
                  <button className='ml-5 border px-8 py-2 mt-t font-bold rounded-full bg-black text-white border-black'>
                    see all the jobs you posted
                  </button>
                </Link>
              </>
            ) : (
              <>
                <Link href={`/dashboard`}>
                  <button className='ml-5 border px-8 py-2 mt-t font-bold rounded-full bg-black text-white border-black'>
                    see all the jobs you applied to
                  </button>
                </Link>
              </>
            )}
          </>
        )}
      </div>
    </div>
  );
}

export async function getServerSideProps(context) {
  const session = await getSession(context);
  let jobs = await getJobs(prisma);
  jobs = JSON.parse(JSON.stringify(jobs));

  let user = await getUser(session.user.id, prisma);
  user = JSON.parse(JSON.stringify(user));
  return {
    props: {
      jobs,
      user,
    },
  };
}
