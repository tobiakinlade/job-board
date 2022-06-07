import { useState } from 'react';
import Router, { useRouter } from 'next/router';
import { useSession } from 'next-auth/react';

export default function Setup() {
  const [name, setName] = useState();
  const [company, setCompany] = useState();
  const { data: session, status } = useSession();
  const loading = status === 'loading';
  const router = useRouter();

  if (loading) return null;

  if (!session || !session.user) {
    router.push('/');
    return null;
  }

  if (!loading && session && session.user.name) {
    router.push('/');
  }

  const handleSubmit = async (e) => {
    e.preventDefault();

    await fetch('/api/setup', {
      body: JSON.stringify({
        name,
        company,
      }),
      headers: {
        'Content-Type': 'application/json',
      },
      method: 'POST',
    });

    session.user.name = name;
    session.user.company = company;
    Router.push('/');
  };
  return (
    <form onSubmit={handleSubmit} className='mt-10 ml-20'>
      <div className='flex-1 mb-5'>
        <div className='flex-1 mb-5'>Add your name</div>
        <input
          type='text'
          name='name'
          value={name}
          onChange={(e) => setName(e.target.value)}
          className='border p-1 text-black'
        />
      </div>
      <button className='border px-8 py-2 mt-0 mr-8 font-bold rounded-full color-accent-contrast hover:bg-color-accent-hover'>
        Save
      </button>
    </form>
  );
}
