using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SetDepthMode : MonoBehaviour
{

	// Use this for initialization
	void Start ()
	{
		Camera cam = GetComponent<Camera> ();
		cam.depthTextureMode = DepthTextureMode.Depth;
	}
}
