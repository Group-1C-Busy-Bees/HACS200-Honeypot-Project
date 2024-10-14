#!/bin/bash

# Check if two arguments (filename and number of times) are provided
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 filename number_of_times"
  exit 1
fi

# Assign arguments to variables
filename=$1
num_times=$2

# The line to append
lorem="Lorem ipsum odor amet, consectetuer adipiscing elit. Montes commodo urna sollicitudin bibend, um torquent. Pulvinar cubilia dapibus cras condimentum penatibus odio. Iaculis pretium per tellus etiam consequat quis? Elit dui penatibus condimentum leo,  donec ligula etiam tempor. Sit erat facilisi aliquam nam fusce magna blandit convallis. Rutrum, nullam quisque nam consectetur sed penatibus. Facilisis nisl pulvinar suspendisse habitant feugiat."

# Append the line the specified number of times
for ((i=1; i<=num_times; i++))
do
  echo "$lorem" >> "$filename"
done


