﻿using UnityEngine;
using System.Collections;

public class DebugDrawDepth : MonoBehaviour
{

	[SerializeField] RenderTexture m_colorTex;
	[SerializeField] RenderTexture m_depthTex;

	[SerializeField] Shader shader;
	[SerializeField] Shader debugshader;

	Camera cam;
	Material mat;
	Material debugmat;

	void Start ()
	{
		cam = GetComponent<Camera> ();
		cam.depthTextureMode = DepthTextureMode.Depth;

		m_colorTex = new RenderTexture (Screen.width, Screen.height, 0, RenderTextureFormat.ARGB32);
		m_colorTex.Create ();

		m_depthTex = new RenderTexture (Screen.width, Screen.height, 24, RenderTextureFormat.Depth);
		m_depthTex.Create ();

		cam.SetTargetBuffers (m_colorTex.colorBuffer, m_depthTex.depthBuffer);

	}

	void Update ()
	{
		cam.SetTargetBuffers (m_colorTex.colorBuffer, m_depthTex.depthBuffer);

	}

	void OnPostRender ()
	{
		if (mat == null) {
			mat = new Material (shader);
		}

		if (debugmat == null) {
			debugmat = new Material (debugshader);
		}
			

//		Rect r2 = new Rect (0, 280, 128, 72);
//		Graphics.DrawTexture (r2, m_depthTex, debugmat);

		Graphics.SetRenderTarget (null);
		Graphics.Blit (m_colorTex, mat);
//
//		Rect r1 = new Rect (0, 200, 128, 72);
//		Graphics.DrawTexture (r1, m_colorTex, debugmat);
	}

	//	void OnGUI ()
	//	{
	//		//repaint以外のguiイベントで呼び出されてたらreturn!
	//		if (Event.current.type != EventType.Repaint) {
	//			return;
	//		}
	//
	//		Rect r1 = new Rect (0, 200, 128, 72);
	//		Graphics.DrawTexture (r1, m_colorTex, debugmat);
	//
	//		Rect r2 = new Rect (0, 280, 128, 72);
	//		Graphics.DrawTexture (r2, m_depthTex, debugmat);
	//	}

} 