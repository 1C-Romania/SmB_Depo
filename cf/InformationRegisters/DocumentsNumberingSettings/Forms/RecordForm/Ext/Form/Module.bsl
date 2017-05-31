&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Items.DocumentType.ChoiceList.Clear();
	
	AvailableTypes = Metadata.InformationRegisters.DocumentsNumberingSettings.Dimensions.DocumentType.Type;
	
	For Each MetadataObject In Metadata.Documents Do
		
		EmptyRef = Documents[MetadataObject.Name].EmptyRef();
		
		If AvailableTypes.ContainsType(TypeOf(EmptyRef)) Then
			Items.DocumentType.ChoiceList.Add(Documents[MetadataObject.Name].EmptyRef(),MetadataObject.Synonym);
		EndIf;
		
	EndDo;
	
	Items.DocumentType.ChoiceList.SortByPresentation();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	LabelMaxNumberText = Items.DecorationLabelMaxNumber.Title;
	UpdateDialog();
EndProcedure

&AtClient
Procedure DocumentTypeOnChange(Item)
	UpdateDialog();
EndProcedure

&AtClient
Procedure PrefixOnChange(Item)
	UpdateDialog();
EndProcedure

&AtClient
Procedure InitialCounterOnChange(Item)
	UpdateDialog();
EndProcedure

&AtClient
Procedure UpdateDialog()
	
	SampleNumber = TrimAll(DocumentsPostingAndNumberingAtClientAtServer.ReplacePrefixTokens_Date(Record.Prefix, CurrentDate())) + TrimAll(Record.InitialCounter);
	
	If Record.DocumentType = Undefined Then
		Items.DecorationLabelMaxNumber.Title = NStr("en='Please, choose document type.';pl='Wybierz typ dokumentu.';ru='Выберите тип документа.'");
	Else
		Items.DecorationLabelMaxNumber.Title = Alerts.ParametrizeString(LabelMaxNumberText, New Structure("P1", ObjectsExtensionsAtServer.GetDocumentNumberLength(Record.DocumentType)));
	EndIf;
	
EndProcedure