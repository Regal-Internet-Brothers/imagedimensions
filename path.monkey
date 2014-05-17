Strict

Public

' Imports:
Import stringutil

' Functions:

' 'FixDataPath' command by Mark Sibly:
Function FixDataPath:String(path:String)
	' Local variable(s):
	Local i:=path.Find(ColonSlash)
	
	If (i<>-1 And path.Find(Slash)=i+1) Then Return path
	If (path.StartsWith(DotSlash) Or path.StartsWith(Slash)) Then Return path
	
	If (path.StartsWith("data")) Then
		Return path
	Else
		Return "data"+Slash+path
	Endif
End