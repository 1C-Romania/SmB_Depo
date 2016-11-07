#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;  	

	AddressInBasisDocumentsStorage = Parameters.AddressInBasisDocumentsStorage;
	
	If AddressInBasisDocumentsStorage<>"" Then
		BasisDocuments.Load(GetFromTempStorage(AddressInBasisDocumentsStorage));
	EndIf;
		
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OK(Command)
	
	Cancel = False;
	
	CheckFillOfFormAttributes(Cancel);
	
	If Not Cancel Then
		WriteBasisDocumentsToStorage();
		Close(DialogReturnCode.OK);
	EndIf;

EndProcedure

#EndRegion

#Region CommonUseProceduresAndFunctions

// Procedure checks the correctness of the form attributes filling.
//
&AtClient
Procedure CheckFillOfFormAttributes(Cancel)
	
	// Attributes filling check.
	LineNumber = 0;
		
	For Each RowDocumentsBases IN BasisDocuments Do
		LineNumber = LineNumber + 1;
		If Not ValueIsFilled(RowDocumentsBases.BasisDocument) Then
			Message = New UserMessage();
			Message.Text = NStr("en='Column ""Basis document"" is not filled in line ';ru='Не заполнена колонка ""Документ основание"" в строке '")
				+ String(LineNumber)
				+ NStr("en=' of list ""Basis documents"".';ru=' списка ""Документы основания""..'");
			Message.Field = "Document";
			Message.Message();
			Cancel = True;
		EndIf;
	EndDo;
	
EndProcedure // CheckFillFormAttributes()

// The procedure places pick-up results in the storage.
//
&AtServer
Procedure WriteBasisDocumentsToStorage()
	
	BasisDocumentsInStorage = BasisDocuments.Unload(, "BasisDocument");
	PutToTempStorage(BasisDocumentsInStorage, AddressInBasisDocumentsStorage);
	
EndProcedure // WritePickToStorage()

#EndRegion



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
