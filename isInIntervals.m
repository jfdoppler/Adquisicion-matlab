function [ belongs ] = isInIntervals(x, intervals)
%UNTITLED checks if x is in the intervals 
  belongs=0;
  for i =1:(length(intervals)/2)
    if x>=intervals(2*i-1) && x<intervals(2*i), belongs=1; end
  end    
end

