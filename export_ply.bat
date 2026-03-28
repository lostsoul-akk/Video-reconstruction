@echo off
set "COLMAP=C:\Users\User\Desktop\Video Reconstruction\MUG RECONSTRUCTION 2\01 COLMAP\colmap.exe"
set "SPARSE=C:\Users\User\Desktop\Video Reconstruction\MUG RECONSTRUCTION 2\04 SCENES\VID_20260327_082519\sparse\0\points3D.ply"

"%COLMAP%" model_converter ^
  --input_path  "%SPARSE%" ^
  --output_path "%SPARSE%" ^
  --output_type PLY

echo Done. Check the sparse\0 folder for points3D.ply
pause