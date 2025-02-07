if [ -z "$1" ]; then
  echo "Error: Specify the file"
  exit 1
fi

export FILE_PATH="$1"

rails server -b 0.0.0.0 -p 3000
