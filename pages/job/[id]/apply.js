import { useState } from 'react'
import { useRouter } from 'next/router'
import Link from 'next/link'
import { getJob, getUser } from 'lib/data'
import prisma from 'lib/prisma'
import { useSession, getSession } from 'next-auth/react'

export default function Apply({ job, user }) {
  console.log(job.author.id)
  console.log(user.id)
  const [coverLetter, setCoverLetter] = useState('')
  const { data: session } = useSession()
  const router = useRouter()

  const handleSubmit = async (e) => {
    e.preventDefault()

    await fetch('/api/application', {
      body: JSON.stringify({
        coverLetter,
        job: job.id,
      }),
      headers: {
        'Content-Type': 'application/json',
      },
      method: 'POST',
    })

    router.push('/dashboard')
  }

  if (!session) return null
  return (
    <form onSubmit={handleSubmit}>
      <div className='flex flex-col w-1/2 mx-auto'>
        <div className='mt-10'>
          <div className='text-center p-4 m-4'>
            <Link href={`/job/${job.id}`}>
              <a href=''>back</a>
            </Link>
          </div>
          <div className='text-center p-4 m-4'>
            <h2 className='mb-10 text-4xl font-bold'>
              Apply to the job {job.title}
            </h2>
          </div>

          <div className='mb-4 mt-20'>
            <div className='pl-16 pr-16 -mt-16'>
              <p className='text-base font-normal mt-3'>{job.description}</p>
              <div className='mt-4'>
                <h4 className='inline'>Posted by</h4>
                <div className='inline'>
                  <div className='ml-3 -mt-6 inline'>
                    <span>
                      <Link href={`/company/${job.author.id}`}>
                        <a href=''>
                          <span className='text-base font-medium color-primary underline'>
                            {job.author.name}
                          </span>
                        </a>
                      </Link>
                    </span>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {user.id === job.author.id ? (
            <p className='mt-10 ml-8'>This job was posted by you</p>
          ) : (
            <>
              <div className='pt-2 mt-2 mr-1'>
                <textarea
                  className='border p-4 w-full text-lg font-medium bg-transparent outline-none color-primary'
                  required
                  placeholder='Cover letter'
                  cols={50}
                  rows={6}
                  onChange={(e) => setCoverLetter(e.target.value)}
                />
              </div>
              <div className='mt-5'>
                <button className='border float-right px-8 py-2 mt-0 font-bold rounded-full'>
                  Apply to this job
                </button>
              </div>
            </>
          )}
        </div>
      </div>
    </form>
  )
}

export async function getServerSideProps(context) {
  const session = await getSession(context)

  let job = await getJob(context.params.id, prisma)
  job = JSON.parse(JSON.stringify(job))

  let user = await getUser(session?.user.id, prisma)
  user = JSON.parse(JSON.stringify(user))

  return {
    props: {
      job,
      user,
    },
  }
}
