

require 'allreduce'

id = arg[1] or error('please provide a unique id')
jobs = arg[2] or error('please provide a total nb of jobs')

allreduce.init('localhost', id, jobs)

for i = 1,10 do
   -- do some stuff
   a = torch.randn(10):float()

   -- average arrays from all jobs
   allreduce.accumulate(a)

   -- print average:
   print(a)
end
