Strict

Public

' Preprocessor related:
#LOAD_IMG_DIMENSIONS = True
#LOAD_IMG_DIMENSIONS_PATHS = True
#LOAD_IMG_DIMENSIONS_CHECKEXT = False

' Imports:
Import regal.byteorder

' Don't worry about this, it doesn't concern anyone but me:
#If AUTOSTREAM_IMPLEMENTED
	Import regal.autostream
#Else
	#If LOAD_IMG_DIMENSIONS_PATHS
		Import brl.filestream
	#End
#End

#If LOAD_IMG_DIMENSIONS
	' Constant variable(s):
	
	' Output-data related:
	
	' The size of the default output-array.
	Const IMAGEDIMENSIONS_SIZE:Int = 2
	
	Const IMAGEDIMENSION_WIDTH:Int = 0
	Const IMAGEDIMENSION_HEIGHT:Int = 1
	
	' PNG related:
	Const PNG_CHARENCODE:String = "ascii"
	
	Const PNG_ID:String = "PNG"
	Const PNG_ChunkType_Length:Int = 4
	Const PNG_ChunkType_IHDR:String = "IHDR"

	' JPEG related:
	Const JPEG_CHARENCODE:String = "ascii"
	Const JPEG_MARKER_SOI:Int = $FFFFFFD8 ' 0xD8 - Start of image.
	
	' GIF related:
	Const GIF_ID_Base:String = "GIF"
	Const GIF_CHARENCODE:String = "ascii"
	Const GIF_ID_EXT_LEN:Int = 3
	
	' Global variable(s):
	
	' JPEG related:
	
	' An array of frame-start codes:
	Global JPEG_MARKERS_FRAME:Int[] = [$FFFFFFC0, $FFFFFFC1, $FFFFFFC2, $FFFFFFC3, $FFFFFFC4, $FFFFFFC5,
										$FFFFFFC6, $FFFFFFC7, $FFFFFFC8, $FFFFFFC9, $FFFFFFCA, $FFFFFFCB,
											$FFFFFFCD, $FFFFFFCE, $FFFFFFCF]
	
	Global JPEG_MARKERS_EOF:Int[] = [$FFFFFFDA, $FFFFFFD9] ' 0xDA, 0xD9

	' Functions:
	
	' This command generates an image-dimension container.
	Function GenerateImageDimensionContainer:Int[]()
		Return New Int[IMAGEDIMENSIONS_SIZE]
	End
	
	' This command detects if an image-dimension-array is in working order.
	Function ValidImageDimensions:Bool(Dimensions:Int[], Offset:Int=0)
		' Check for errors:
		
		' Make sure we can even check the container:
		If (InvalidImageDimensionContainer(Dimensions, Offset)) Then
			' The container is not in working order, notify the user.
			Return False
		Endif
		
		' Make sure the dimensions aren't zero:
		If (Dimensions[Offset+IMAGEDIMENSION_WIDTH] = 0) Then Return False
		If (Dimensions[Offset+IMAGEDIMENSION_HEIGHT] = 0) Then Return False
		
		' Return the default response.
		Return True
	End
	
	' This simply inverts the response of 'ValidImageDimensions'.
	Function InvalidImageDimensions:Bool(Dimensions:Int[], Offset:Int=0)
		Return Not ValidImageDimensions(Dimensions, Offset)
	End
	
	' This command detects if an image-dimension container is the correct size.
	Function ValidImageDimensionContainer:Bool(Container:Int[], Offset:Int=0)
		' Check if this is a valid container:
		If (Container.Length()-Offset < IMAGEDIMENSIONS_SIZE) Then
			' This container is too small, notify the user.
			Return False
		Endif
		
		' Return the default response.
		Return True
	End
	
	' This simply inverts the response of 'ValidImageDimensionContainer'.
	Function InvalidImageDimensionContainer:Bool(Container:Int[], Offset:Int=0)
		Return Not ValidImageDimensionContainer(Container, Offset)
	End
		
	' These commands only support 'GIF', 'PNG' and 'JPG' based file-formats:
	#If LOAD_IMG_DIMENSIONS_PATHS
		Function LoadImageDimensions:Int[](Path:String)
			Return LoadImageDimensions(Path, GenerateImageDimensionContainer())
		End
		
		Function LoadImageDimensions:Int[](Path:String, Output:Int[], Output_Offset:Int=0)
			#If LOAD_IMG_DIMENSIONS_CHECKEXT
				' Make sure the file-extension is supported:
				If (StripExt(Path).ToLower() <> "png") Then
					If (StripExt(Path).ToLower() <> "jpg") Then
						If (StripExt(Path).ToLower() <> "gif") Then
							Return [0, 0]
						Endif
					Endif
				Endif
			#End
			
			' Generate a file-stream.
			#If AUTOSTREAM_IMPLEMENTED
				Local S:= OpenAutoStream(Path, "r")
			#Else
				Local S:= FileStream.Open(Path, "r")
			#End
			
			' Call the main implementation.
			Return LoadImageDimensions(S, Output, Output_Offset, False, False)
		End
	#End
	
	Function LoadImageDimensions:Int[](S:Stream, SeekBackToOrigin:Bool=False, StreamIsCustom:Bool=True)
		Return LoadImageDimensions(S, GenerateImageDimensionContainer(), 0, SeekBackToOrigin, StreamIsCustom)
	End
	
	Function LoadImageDimensions:Int[](S:Stream, Output:Int[], Output_Offset:Int=0, SeekBackToOrigin:Bool=False, StreamIsCustom:Bool=True)
		' Make sure we can even use the array:
		If (InvalidImageDimensionContainer(Output, Output_Offset)) Then
			' In this situation, we should return an empty array. (The 'Output' array isn't in working order)
			Return []
		Endif
		
		' For the sake of error detection, set the needed elements of 'Output' to zero:
		Output[Output_Offset+IMAGEDIMENSION_WIDTH] = 0
		Output[Output_Offset+IMAGEDIMENSION_HEIGHT] = 0
		
		' Check for errors:
		
		' Make sure we can use the input-stream:
		If (S = Null Or S.Eof()) Then
			' The input-stream is not in working order, return the output-array.
			Return Output
		Endif
		
		' Local variable(s):
		Local InitialPosition:= S.Position
		Local ImageFound:Bool = False
				
		If (Not ImageFound And S <> Null) Then
			' Skip the safety byte.
			S.Seek(S.Position+1) ' 1
			
			' Try to read the PNG ID-string from the file:
			If (S.ReadString(PNG_ID.Length(), PNG_CHARENCODE).ToUpper() = PNG_ID) Then
				' Don't bother with the line-ending bytes.
				S.Seek(S.Position+4)
				
				' The first chunk is always the IHDR header, but just to be safe, we'll check each chunk:
				While (S <> Null And Not S.Eof())
					' Just in case, we'll get the chunk size:
					Local ChunkLength:Int = NToHL(S.ReadInt())
					
					' Just in case, we'll check the chunk-type:
					If (ChunkLength) Then
						If (S.ReadString(PNG_ChunkType_Length, PNG_CHARENCODE).ToUpper() = PNG_ChunkType_IHDR) Then
							Output[Output_Offset+IMAGEDIMENSION_WIDTH] = Abs(NToHL(S.ReadInt())) 'NToHL(S.ReadInt())
							Output[Output_Offset+IMAGEDIMENSION_HEIGHT] = Abs(NToHL(S.ReadInt())) 'NToHL(S.ReadInt())
							
							ImageFound = True
							
							' There's usually more to this chunk, but for now, we're done:
							Exit
						Else
							S.Seek(S.Position+ChunkLength)
						Endif
					Endif
				Wend
			Endif
		Endif
		
		If (Not ImageFound And S <> Null) Then
			S.Seek(InitialPosition)
			
			' Make sure we're dealing with a JPEG.
			If (S.ReadByte() = $FFFFFFFF And S.ReadByte() = JPEG_MARKER_SOI) Then				
				While (S <> Null And Not S.Eof())
					If (S.ReadByte() = $FFFFFFFF) Then ' 0xFFFFFFFF						
						Local Marker:Int = S.ReadByte()
						
						' Skip the marker's padding.
						'S.Seek(S.Position+1) ' S.ReadByte()
						
						Local FrameCodeFound:Bool = False
						
						For Local C:= Eachin JPEG_MARKERS_FRAME
							If (Marker = C) Then
								FrameCodeFound = True
								
								Exit
							Endif
						Next
						
						If (FrameCodeFound) Then							
							' Skip the length.
							S.Seek(S.Position+2)
							
							' Skip any extra bytes:
							S.Seek(S.Position+1)
							
							Output[Output_Offset+IMAGEDIMENSION_HEIGHT] = Abs(NToHS(S.ReadShort())) 'NToHS(S.ReadShort())
							Output[Output_Offset+IMAGEDIMENSION_WIDTH] = Abs(NToHS(S.ReadShort())) 'NToHS(S.ReadShort())
							
							ImageFound = True
							
							Exit
						Else
							Local EOFResponse:Bool = False
							
							For Local C:= Eachin JPEG_MARKERS_EOF
								If (Marker = C) Then
									EOFResponse = True
									
									Exit
								Endif
							Next
							
							If (EOFResponse) Then Exit
							
							Select Marker
								Default
									Local Length:Int = NToHS(S.ReadShort())
									
									If (Length < 2) Then
										Exit
									Endif
									
									Length -= 2
									
									'If (Length > 0) Then
									S.Seek(S.Position+Length)
									'Endif
							End Select
						Endif
					Endif
				Wend
			Endif
		Endif
		
		If (Not ImageFound And S <> Null) Then
			S.Seek(InitialPosition)
			
			If (S.ReadString(GIF_ID_Base.Length, GIF_CHARENCODE) = GIF_ID_Base) Then
				S.Seek(S.Position+GIF_ID_EXT_LEN)
				
				Output[Output_Offset+IMAGEDIMENSION_WIDTH] = Abs(S.ReadShort()) 'S.ReadShort()
				Output[Output_Offset+IMAGEDIMENSION_HEIGHT] = Abs(S.ReadShort()) 'S.ReadShort()
				
				ImageFound = True
				
				'Exit
			Endif
		Endif
		
		#Rem
		If (Not ImageFound And S <> Null) Then
			S.Seek(InitialPosition)
		Endif
		#End
		
		If (SeekBackToOrigin And S <> Null) Then
			S.Seek(InitialPosition)
		Endif
		
		' Close the generated stream:
		If (S <> Null) Then
			#If AUTOSTREAM_IMPLEMENTED
				CloseAutoStream(S, StreamIsCustom)
			#Else
				If (Not StreamIsCustom) Then
					S.Close()
				Endif
			#End
			
			S = Null
		Endif
		
		' Return the dimension-array.
		Return Output
	End
	
	' Classes:
	' Nothing so far.
#End