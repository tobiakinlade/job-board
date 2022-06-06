import prisma from 'lib/prisma';
import { faker } from '@faker-js/faker';

const generateFakeJob = (user) => ({
  title: faker.company.catchPhrase(),
  description: faker.lorem.paragraphs(),
  author: {
    connect: {
      id: user.id,
    },
  },
});

export default async function handler(req, res) {
  if (req.method !== 'POST') res.end();

  if (req.body.task === 'clean-database') {
    await prisma.job.deleteMany({});
    await prisma.user.deleteMany({});
  }

  if (req.body.task === 'generate_one_job') {
    const users = await prisma.user.findMany({
      where: {
        company: true,
      },
    });
    await prisma.job.create({
      data: generateFakeJob(users[0]),
    });
  }

  if (req.body.task === 'generate_users_and_jobs') {
    let count = 0;

    while (count < 10) {
      await prisma.user.create({
        data: {
          name: faker.internet.userName().toLowerCase(),
          email: faker.internet.email().toLowerCase(),
          company: faker.datatype.boolean(),
        },
      });
      count++;
    }

    const users = await prisma.user.findMany({
      where: {
        company: true,
      },
    });

    users.forEach(async (user) => {
      await prisma.job.create({
        data: generateFakeJob(user),
      });
    });
  }

  res.end();
}
