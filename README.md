# Unity-InteriorMapping

// The MIT License
// Copyright © 2013 Gil Damoiseaux
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software 
// and associated documentation files (the "Software"), to deal in the Software without restriction, 
// including without limitation the rights to use, copy, modify, merge, publish, distribute, 
// sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is 
// furnished to do so, subject to the following conditions: The above copyright notice and this
// permission notice shall be included in all copies or substantial portions of the Software. 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT 
// NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. 
// IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, 
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH 
// THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

This project is provided as as, for learning purpose.
You can use it freely in commercial and personnal projects
No support will be provided ... it has been only tested on windows/DX11 platform so far.

The shader requires :

*An interior atlas with the albedo of the interior ... 4x4 textures:
	- first column is the ground texture
	- second column is the ceiling texture
	- third one is the sidewall texture (streched x2)
	- fourth one is the backwall texture (stretched x2)
*window atlas with 4 variations of the window (open->closed window blinds)
*window normal map
*window Roughness/Metalness/Glass texture (glass is used as mask for some effects in the shader.)

Optional :
*Decoration atlas with 4 walls random feature/poster/whatever you want ... 

I hope you'll enjoy it, have fun!

A samples scene is provided with several variations of the shader.