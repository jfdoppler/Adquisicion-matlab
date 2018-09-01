function [normalizada]=normalizar(entrada)
normalizada=1.998*(entrada-(max(entrada)+min(entrada))/2.)/(max(entrada)-min(entrada));