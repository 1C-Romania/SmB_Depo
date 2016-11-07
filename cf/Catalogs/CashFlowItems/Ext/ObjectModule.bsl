#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not IsFolder Then
	
		If Not IsBlankString(CorrespondingAccount) Then
			If IsBlankString(StrReplace(CorrespondingAccount, ".", "")) Then
				CorrespondingAccount = "";
			ElsIf Right(TrimAll(CorrespondingAccount), 1) = "." Then
				CorrespondingAccount = Left(TrimAll(CorrespondingAccount), StrLen(TrimAll(CorrespondingAccount)) - 1);
			EndIf;
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf