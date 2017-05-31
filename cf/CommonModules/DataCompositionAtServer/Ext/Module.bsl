Function FindDCSFielByFullName(Items, FullName) Export

	NamePartsArray = GetPartsFromFullName(FullName);
	PartsCount = NamePartsArray.Count();
	
	CurrentName = NamePartsArray[0];
	Field = FindDCSFieldByName(Items, CurrentName);
	If Field = Undefined Then
		Return Undefined;
	EndIf;
	
	For Cnt = 2 to PartsCount Do
		CurrentName = CurrentName +"." + NamePartsArray[Cnt-1];
		Field = FindDCSFieldByName(Field.Items, CurrentName);
		If Field = Undefined Then
			Return Undefined;
		EndIf;
	EndDo;
	
	Return Field;

EndFunction

Function FindDCSFieldByName(Items, Name)
	
	For Each Item In Items Do
		If Upper(String(Item.Field)) = Upper(Name) Then
			Return Item;
		EndIf;
	EndDo;
	
	Return Undefined;
	
EndFunction // FindDCSFieldByName()

////////////////////////////////////////////

Function GetPartsFromFullName(FullName)

	PartsArray = New Array;
	NameAsString = FullName;
	
	While Not IsBlankString(NameAsString) Do
		If Left(NameAsString, 1) = "[" Then
			
			Pos = Find(NameAsString, "]");
			If Pos = 0 Then
				PartsArray.Add(Mid(NameAsString, 2));
				NameAsString = "";
			Else
				PartsArray.Add(Mid(NameAsString, 1, Pos));
				NameAsString = Mid(NameAsString, Pos + 2);
			EndIf;
			
		Else
			
			Pos = Find(NameAsString, ".");
			If Pos = 0 Then
				PartsArray.Add(NameAsString);
				NameAsString = "";
			Else
				PartsArray.Add(Left(NameAsString, Pos - 1));
				NameAsString = Mid(NameAsString, Pos + 1);
			EndIf;
		EndIf;
	EndDo;
	
	Return PartsArray;

EndFunction // GetPartsFromFullName()
