import React, { useEffect, useState } from "react";
import axios from "axios";

export default function App() {
  const [jsonData, setJsonData] = useState(null);
  const [lobList, setLobList] = useState([]);
  const [targetApps, setTargetApps] = useState([]);
  const [lob, setLob] = useState("");
  const [targetApp, setTargetApp] = useState("");

  const [projectName, setProjectName] = useState("");
  const [releaseType, setReleaseType] = useState("");
  const [releaseDescription, setReleaseDescription] = useState("");

  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState("");


  // --------------------------------------------------
  // 1. Load JSON from central repo
  // --------------------------------------------------
  useEffect(() => {

    axios
      .get(
        "https://raw.githubusercontent.com/nehaa13/central_repository/main/CL1/Scxml.json"
      )
      .then((res) => {
        setJsonData(res.data);
        setLobList(Object.keys(res.data.SCXML_TARGET_APP_LISTS));
      })
      .catch((err) => console.error("Error loading JSON:", err));
  }, []);


  // --------------------------------------------------
  // 2. When LOB changes → update Target App dropdown
  // --------------------------------------------------
  useEffect(() => {
    if (!jsonData || !lob) return;

    const apps = jsonData.SCXML_TARGET_APP_LISTS[lob];
    setTargetApps(apps);
    setTargetApp("");   // reset target app when LOB changes
  }, [lob, jsonData]);


  // --------------------------------------------------
  // 3. Trigger GitHub Workflow
  // --------------------------------------------------
  const triggerWorkflow = async () => {
    setLoading(true);
    setMessage("");

    try {
      await axios.post(
        "https://api.github.com/repos/nehaa13/SCXML/actions/workflows/scxml.yml/dispatches",
        {
          ref: "main",
          inputs: {
            lob,
            target_app: targetApp,
            project_name: projectName,
            release_type: releaseType,
            release_description: releaseDescription,
          },
        },
        {
          headers: {
            Authorization: `token ${process.env.REACT_APP_GITHUB_TOKEN}`,
            Accept: "application/vnd.github.v3+json",
          },
        }
      );

      setMessage("Workflow triggered successfully!");
    } catch (err) {
      console.error(err);
      setMessage("Error: Workflow trigger failed.");
    }

    setLoading(false);
  };


  // --------------------------------------------------
  // 4. UI Rendering
  // --------------------------------------------------
  return (
    <div className="container">

      <h1>SCXML Deployment UI</h1>

      {!jsonData ? (
        <p>Loading JSON...</p>
      ) : (
        <div className="form">

          {/* LOB Dropdown */}
          <label>LOB</label>
          <select value={lob} onChange={(e) => setLob(e.target.value)}>
            <option value="">Select LOB</option>
            {lobList.map((item) => (
              <option key={item}>{item}</option>
            ))}
          </select>


          {/* Target App Dropdown */}
          <label>Target App</label>
          <select
            value={targetApp}
            onChange={(e) => setTargetApp(e.target.value)}
            disabled={!lob}
          >
            <option value="">Select Target App</option>
            {targetApps.map((app) => (
              <option key={app}>{app}</option>
            ))}
          </select>


          {/* Project Name */}
          <label>Project Name</label>
          <input
            type="text"
            value={projectName}
            onChange={(e) => setProjectName(e.target.value)}
          />

          {/* Release Type */}
          <label>Release Type</label>
          <input
            type="text"
            value={releaseType}
            onChange={(e) => setReleaseType(e.target.value)}
          />

          {/* Release Description */}
          <label>Release Description</label>
          <textarea
            value={releaseDescription}
            onChange={(e) => setReleaseDescription(e.target.value)}
          />


          {/* Trigger Button */}
          <button onClick={triggerWorkflow} disabled={loading}>
            {loading ? "Triggering..." : "Trigger Workflow"}
          </button>


          {/* Response Message */}
          {message && <p className="message">{message}</p>}
        </div>
      )}
    </div>
  );
}
