using UnityEngine;
using System.Collections;

public class AutoRotate : MonoBehaviour
{
	public Vector3 BaseRotation;
	public Vector3 RotationSpeed;

	// Update is called once per frame
	void Update()
	{
		transform.rotation = Quaternion.Euler(BaseRotation + RotationSpeed*Time.fixedTime);
	}
}
