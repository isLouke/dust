#!/bin/bash
echo
echo "=== Deleting Output and Postprocess directories ==="
echo

echo "Removing Output"
rm -rf ./Output/
echo "Removing Postprocess"
rm -rf ./Postprocess/

echo 
echo "========= Creating necessary directories =========="
echo 

echo "Create Output"
mkdir Output
echo "Create Output/Debug"
mkdir ./Output/Debug
echo "Create Postprocess"
mkdir Postprocess

echo
echo "Done."