useEffect(() => {
  axios
    .get("https://raw.githubusercontent.com/nehaa13/central_repository/main/CL1/Scxml.json")
    .then((res) => setJsonData(res.data))
    .catch((err) => console.error(err));
}, []);
