
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ActualEDs = ElectronicDocumentsReUse.GetEDActualKinds();
	
	For Each EDKind IN ActualEDs Do
		Rows = SignableEDKinds.FindRows(New Structure("EDKind", EDKind));
		If Rows.Count() = 0 Then
			NewRecord = SignableEDKinds.Add();
			NewRecord.DSCertificate = Parameters.Filter.DSCertificate;
			NewRecord.EDKind = EDKind;
		EndIf;
	EndDo;
	
	SignableEDKinds.Sort("EDKind");
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If DataChanged Then
		SaveChangesAtServer();
	EndIf;
	
EndProcedure

&AtClient
Procedure UseOnChange(Item)
	
	DataChanged = True;
	
EndProcedure

&AtServer
Procedure SaveChangesAtServer()
	
	InformationRegisters.DigitallySignedEDKinds.SaveSignedEDKinds(
		SignableEDKinds.Filter.DSCertificate.Value, SignableEDKinds.Unload());
	
EndProcedure

&AtClient
Procedure SelectAll(Command)
	
	ChangeMarker(True);
	
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	
	ChangeMarker(False);
	
EndProcedure

&AtClient
Procedure ChangeMarker(Mark)
	
	For Each String IN SignableEDKinds Do
		String.Use = Mark;
	EndDo;
	DataChanged = True;
	
EndProcedure