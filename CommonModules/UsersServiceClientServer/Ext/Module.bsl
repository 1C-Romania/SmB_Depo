////////////////////////////////////////////////////////////////////////////////
// Subsystem "Users".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Generates login based on the full user name.
Function GetShortNameOfIBUser(Val DescriptionFull) Export
	
	Separators = New Array;
	Separators.Add(" ");
	Separators.Add(".");
	
	ShortName = "";
	For Counter = 1 To 3 Do
		
		If Counter <> 1 Then
			ShortName = ShortName + Upper(Left(DescriptionFull, 1));
		EndIf;
		
		SeparatorPosition = 0;
		For Each Delimiter IN Separators Do
			CurrentSeparatorPosition = Find(DescriptionFull, Delimiter);
			If CurrentSeparatorPosition > 0
			   AND (    SeparatorPosition = 0
			      OR SeparatorPosition > CurrentSeparatorPosition ) Then
				SeparatorPosition = CurrentSeparatorPosition;
			EndIf;
		EndDo;
		
		If SeparatorPosition = 0 Then
			If Counter = 1 Then
				ShortName = DescriptionFull;
			EndIf;
			Break;
		EndIf;
		
		If Counter = 1 Then
			ShortName = Left(DescriptionFull, SeparatorPosition - 1);
		EndIf;
		
		DescriptionFull = Right(DescriptionFull, StrLen(DescriptionFull) - SeparatorPosition);
		While Separators.Find(Left(DescriptionFull, 1)) <> Undefined Do
			DescriptionFull = Mid(DescriptionFull, 2);
		EndDo;
	EndDo;
	
	Return ShortName;
	
EndFunction

#EndRegion
