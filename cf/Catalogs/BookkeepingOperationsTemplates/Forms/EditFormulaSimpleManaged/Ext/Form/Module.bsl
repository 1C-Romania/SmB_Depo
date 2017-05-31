#Region BaseFormsProcedures
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	For Each Attribute In GetAttributes() Do
		FoundValue = Undefined;
		If Parameters.Property(Attribute.Name, FoundValue) Then
			ThisForm[Attribute.Name] = FoundValue;
		EndIf;
	EndDo;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	CopyFormData(ThisForm.FormOwner.Object,Object);
	FillParametersTree();	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	CopyFormData(Object,ThisForm.FormOwner.Object);	
	If OpenedFromWizard Then
		If RootModified Then
			ThisForm.FormOwner.FormOwner.Modified = True;			
		EndIf;	
	Else
		If RootModified Or ValueSelected Then
			ThisForm.FormOwner.Modified = True;
		EndIf;			
	EndIf;	
EndProcedure

#EndRegion

#Region FormsCommands

&AtClient
Procedure Select(Command)
	Formula = GetFormulaAtServer();
	
	If IsBlankString(Formula) And Not IsBlankString(FormulaPresentation) Then
		ShowMessageBox( , Nstr("en = 'There are was errors in formula. Please correct them and try again!'; pl = 'Znaleziono błędy we wzorze. Nalezy poprawić błędy i spróbować ponownie!'"));		
		Return;
	Else
		ValueSelected = True;		
		Close(Formula);		
	EndIf;		
EndProcedure

&AtClient
Procedure SelectParameter(Command)
	SetFormula();
EndProcedure

&AtClient
Procedure NewParameter(Command)
	If OpenedFromWizard Then
		ItemForm = ThisForm.FormOwner.FormOwner;
	Else	
		ItemForm = ThisForm.FormOwner;		
	EndIf;
	DocumentsFormAtclient.CreateNewParameter(ItemForm,ThisForm,TableBoxName);
EndProcedure

&AtClient
Procedure NewParameterOnCloseResult(Result, AdditionalParameters) Export
	If Result <> Undefined Then
		FillParametersTree();
		RootModified = True;
	EndIf;
EndProcedure

&AtClient
Procedure EditParameter(Command)
	If Items.ParametersTree.CurrentData <> Undefined Then
		ParameterName = Items.ParametersTree.CurrentData.ParameterName;
		If Not IsBlankString(ParameterName) AND Find(ParameterName, ".") = 0 Then
			RowID = Object.Parameters.IndexOf(Object.Parameters.FindRows(New Structure("Name", ParameterName))[0]);		
			FormParameters = DocumentsFormAtServer.GetParameterStructure(Object,RowID);					
			OpenForm("Catalog.BookkeepingOperationsTemplates.Form.ParameterManaged", FormParameters, ThisForm, ThisForm.UUID, , , New NotifyDescription("NewParameterOnCloseResult", ThisForm));
		EndIf;	
	EndIf;
EndProcedure

#EndRegion

#Region ItemsEvents
&AtClient
Procedure ParametersTreeSelection(Item, SelectedRow, Field, StandardProcessing)
	StandardProcessing = False;
	SetFormula();
EndProcedure

&AtClient
Procedure ParametersTreeOnActivateRow(Item)
	CurrentData = Items.ParametersTree.CurrentData;
	Items.ParametersTreeButtonEdit.Enabled = CurrentData <> Undefined AND Find(Items.ParametersTree.CurrentData.ParameterName, ".") = 0 AND CurrentData.GetItems().Count() = 0;
EndProcedure

&AtClient
Procedure ParametersTreeDragStart(Item, DragParameters, Perform)
	DragParameters.Value = "[" + GetParameterPresentationAtServer(Item.CurrentData.ParameterName) + "]";
	DragParameters.Action = DragAction.Copy;
EndProcedure

#EndRegion

#Region Other

&AtClient
Procedure SetFormula()
	CurrentData = Items.ParametersTree.CurrentData;
	If CurrentData <> Undefined Then
		Items.FormulaPresentation.SelectedText = "[" + GetParameterPresentationAtServer(CurrentData.ParameterName) + "]";
	EndIf;	
EndProcedure

&AtClient
Procedure FillParametersTree()
	If OpenedFromWizard Then
		StrCurrentRecord = DocumentsFormAtClient.GetStrCurrentRecord(ThisForm.FormOwner.FormOwner,TableBoxName);			
	Else
		StrCurrentRecord = DocumentsFormAtClient.GetStrCurrentRecord(ThisForm.FormOwner,TableBoxName);					
	EndIf;		

	FillParametersTreeAtServer(StrCurrentRecord);	
	DocumentsFormAtClient.ExpandTreeRows(Items.ParametersTree,ParametersTree);
	
EndProcedure

&AtServer
Procedure FillParametersTreeAtServer(StrCurrentRecord)
	ParametersTreeObject = FormDataToValue(ParametersTree, Type("ValueTree"));
	Catalogs.BookkeepingOperationsTemplates.FillParametersTree(ThisForm, ParametersTreeObject, TableKind, TableName, False, Undefined,TableBoxName,,StrCurrentRecord.TableBoxCurrentIndexOfRecord, StrCurrentRecord.TableBoxCurrentColumn);	
	ValueToFormData(ParametersTreeObject, ParametersTree);
EndProcedure

&AtServer
Function GetFormulaAtServer()
	Return Catalogs.BookkeepingOperationsTemplates.GetFormulaByFormulaPresentation(FormulaPresentation, TableKind, TableName, TableBoxName,Object.Parameters.Unload());								
EndFunction

&AtServer
Function GetParameterPresentationAtServer(ParameterName)
	Return Catalogs.BookkeepingOperationsTemplates.GetParameterPresentationByName(ParameterName, TableBoxName,Object.Parameters.Unload());							
EndFunction                                                        
#EndRegion




