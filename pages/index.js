import Jobs from 'components/Jobs';
import { getJobs } from 'lib/data';
import prisma from 'lib/prisma';
import { useSession } from 'next-auth/react';
import Head from 'next/head';
import Image from 'next/image';
import { useRouter } from 'next/router';

export default function Home({ jobs }) {
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
      </div>
    </div>
  );
}

export async function getServerSideProps(context) {
  let jobs = await getJobs(prisma);
  jobs = JSON.parse(JSON.stringify(jobs));

  return {
    props: {
      jobs,
    },
  };
}
