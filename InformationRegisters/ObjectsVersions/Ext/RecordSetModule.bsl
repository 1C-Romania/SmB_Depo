#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure BeforeWrite(Cancel, Replacing)
	If DataExchange.Load Then
		Return;
	EndIf;
	
	For Each Record IN ThisObject Do
		Record.DataSize = DataSize(Record.ObjectVersioning);
		ObjVersioning = Record.ObjectVersioning.Get();
		Record.ThereIsVersionData = ObjVersioning <> Undefined;
		If Record.ThereIsVersionData Then
			Record.CheckSum = ObjectVersioning.CheckSum(ObjVersioning);
		EndIf;
	EndDo;
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Function DataSize(Data)
	Return Base64Value(XDTOSerializer.XMLString(Data)).Size();
EndFunction

#EndRegion

#EndIf