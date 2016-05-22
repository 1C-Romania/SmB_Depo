
&AtServer
// The function returns the template structure.
//
Function GetTemplateStructure()
	
	StructureTemplate = Undefined;
	
	If ValueIsFilled(Object.Ref) Then
	StructureTemplate = Object.Ref.Pattern.Get();
	Else
		CopyingValue = Undefined;
		Parameters.Property("CopyingValue", CopyingValue);
		If CopyingValue <> Undefined Then
			StructureTemplate = CopyingValue.Pattern.Get();
		EndIf;
	EndIf;
	
	Return StructureTemplate;
	
EndFunction // GetTemplateStructure()

// Procedure
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Fill in the available fields.
	DataCompositionSchema = DataProcessors.PrintLabelsAndTags.GetTemplate("TemplateFields");
	AddressInStorage = PutToTempStorage(DataCompositionSchema, ThisForm.UUID);
	SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(AddressInStorage));
	
	StructureTemplate = GetTemplateStructure();
	
	If StructureTemplate <> Undefined Then
		// Template importing.
		StructureTemplate.Property("DocumentSpreadsheetEditor", SpreadsheetDocumentField);
		StructureTemplate.Property("VerticalQuantity"    , VerticalQuantity);
		StructureTemplate.Property("CountByHorizontal"  , CountByHorizontal);
		StructureTemplate.Property("CodeType"                  , CodeType);
	Else
		// Creating new template.
		SpreadsheetDocumentField = New SpreadsheetDocument;
		SpreadsheetDocumentField.PrintArea = SpreadsheetDocumentField.Area("R2C2:R20C5");
		ThinDashed = New Line(SpreadsheetDocumentCellLineType.ThinDashed, 1);
		SpreadsheetDocumentField.PrintArea.Outline(ThinDashed,ThinDashed,ThinDashed,ThinDashed);
		CountByHorizontal = 1;
		VerticalQuantity   = 1;
		CodeType = 1; // EAN-13
	EndIf;
	
EndProcedure // OnCreateAtServer()

// Procedure
//
&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Not CheckIsSomethingFitsSomewhere() Then
		Cancel = True;
	Else
		CurrentObject.Pattern = New ValueStorage(PreparePatternTemplateStructure());
	EndIf;
	
EndProcedure // BeforeWriteAtServer()

////////////////////////////////////////////////////////////////////////////////
// Auxiliary functions

// The function of receiving parameters from the row-template of the tabular document.
//
&AtServer
Function GetParameterPositions(TextCell)
	
	Array = New Array;
	
	Begin = -1;
	End  = -1;
	CounterBracketOpening = 0;
	CounterBracketClosing = 0;
	
	For IndexOf = 1 To StrLen(TextCell) Do
		Chr = Mid(TextCell, IndexOf, 1);
		If Chr = "[" Then
			CounterBracketOpening = CounterBracketOpening + 1;
			If CounterBracketOpening = 1 Then
				Begin = IndexOf;
			EndIf;
		ElsIf Chr = "]" Then
			CounterBracketClosing = CounterBracketClosing + 1;
			If CounterBracketClosing = CounterBracketOpening Then
				End = IndexOf;
				
				Array.Add(New Structure("Begin, End", Begin, End));
				
				Begin = -1;
				End  = -1;
				CounterBracketOpening = 0;
				CounterBracketClosing = 0;
				
			EndIf;
		EndIf;
	EndDo;
	
	Return Array;
	
EndFunction // GetParameterPositions()

// The function returns the layout structure of the labels and price tags template.
//
&AtServer
Function PreparePatternTemplateStructure()
	
	TemplateStructure = New Structure;
	TemplateParameters       = New Map;
	ParameterCounter      = 0;
	PrefixNameParameter  = "TemplateParameter";
	
	TemplateAreaLabels = SpreadsheetDocumentField.GetArea();
	
	// Copy the tabular document settings.
	FillPropertyValues(TemplateAreaLabels, SpreadsheetDocumentField);
	
	For ColumnNumber = 1 To TemplateAreaLabels.TableWidth Do
		
		For LineNumber = 1 To TemplateAreaLabels.TableHeight Do
			
			Cell = TemplateAreaLabels.Area(LineNumber, ColumnNumber);
			If Cell.FillType = SpreadsheetDocumentAreaFillType.Template Then
				
				ParameterArray = GetParameterPositions(Cell.Text);
				
				CountParameters = ParameterArray.Count();
				For IndexOf = 0 To CountParameters - 1 Do
					
					Structure = ParameterArray[CountParameters - 1 - IndexOf];
					
					ParameterName = Mid(Cell.Text, Structure.Begin + 1, Structure.End - Structure.Begin - 1);
					If Find(ParameterName, PrefixNameParameter) = 0 Then
						
						LeftPart = Left(Cell.Text, Structure.Begin);
						RightPart = Right(Cell.Text, StrLen(Cell.Text) - Structure.End+1);
						
						StoredParameterNameTemplate = TemplateParameters.Get(ParameterName);
						If StoredParameterNameTemplate = Undefined Then
							ParameterCounter = ParameterCounter + 1;
							Cell.Text = LeftPart + (PrefixNameParameter + ParameterCounter) + RightPart;
							TemplateParameters.Insert(ParameterName, PrefixNameParameter + ParameterCounter);
						Else
							Cell.Text = LeftPart + (StoredParameterNameTemplate) + RightPart;
						EndIf;
						
					EndIf;
					
				EndDo;
				
			ElsIf Cell.FillType = SpreadsheetDocumentAreaFillType.Template Then
				
				If Find(Cell.Parameter, PrefixNameParameter) = 0 Then
					StoredParameterNameTemplate = TemplateParameters.Get(Cell.Parameter);
					If StoredParameterNameTemplate = Undefined Then
						ParameterCounter = ParameterCounter + 1;
						TemplateParameters.Insert(Cell.Parameter, PrefixNameParameter + ParameterCounter);
						Cell.Parameter = PrefixNameParameter + ParameterCounter;
					Else
						Cell.Parameter = StoredParameterNameTemplate;
					EndIf;
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	// Put a barcode to the parameters
	If TemplateParameters.Get(GetParameterNameBarcode()) = Undefined Then
		For Each Draw IN TemplateAreaLabels.Drawings Do
			If Left(Draw.Name,8) = GetParameterNameBarcode() Then
				TemplateParameters.Insert(GetParameterNameBarcode(), PrefixNameParameter + (ParameterCounter+1));
			EndIf;
		EndDo;
	EndIf;
	
	// Replace with an empty picture.
	For Each Draw IN TemplateAreaLabels.Drawings Do
		If Left(Draw.Name,8) = GetParameterNameBarcode() Then
			Draw.Picture = New Picture;
		EndIf;
	EndDo;
	
	TemplateStructure.Insert("TemplateLabel"              , TemplateAreaLabels);
	TemplateStructure.Insert("PrintAreaName"           , SpreadsheetDocumentField.PrintArea.Name);
	TemplateStructure.Insert("CodeType"                    , CodeType);
	TemplateStructure.Insert("TemplateParameters"           , TemplateParameters);
	TemplateStructure.Insert("DocumentSpreadsheetEditor"  , SpreadsheetDocumentField);
	TemplateStructure.Insert("VerticalQuantity"      , VerticalQuantity);
	TemplateStructure.Insert("CountByHorizontal"    , CountByHorizontal);
	
	Return TemplateStructure;
	
EndFunction // PreparePatternTemplateStructure()

// The function checks whether labels and price tags fit the
// list with the specified parameters.
&AtServer
Function CheckIsSomethingFitsSomewhere()
	
	Error = False;
	
	TemplateArea = SpreadsheetDocumentField.GetArea(SpreadsheetDocumentField.PrintArea.Name);
	
	If Not (SpreadsheetDocumentField.PrintArea.Left = 0 AND SpreadsheetDocumentField.PrintArea.Right = 0) Then
		
		ArrayOfTables = New Array;
		For Ind = 1 To CountByHorizontal Do
			ArrayOfTables.Add(TemplateArea);
		EndDo;
		
		While Not SpreadsheetDocumentField.CheckAttachment(ArrayOfTables) Do
			ArrayOfTables.Delete(ArrayOfTables.Count()-1);
		EndDo;
		
		If CountByHorizontal <> ArrayOfTables.Count() Then
			MessageText = NStr("en='Maximal amount by horizontal: '") + ArrayOfTables.Count();
			SmallBusinessServer.ShowMessageAboutError(ThisForm, MessageText, , , "CountByHorizontal", Error);
		EndIf;
		
	EndIf;
	
	If Not (SpreadsheetDocumentField.PrintArea.Top = 0 AND SpreadsheetDocumentField.PrintArea.Bottom = 0) Then
		
		ArrayOfTables = New Array;
		For Ind = 1 To VerticalQuantity Do
			ArrayOfTables.Add(TemplateArea);
		EndDo;
		
		While Not SpreadsheetDocumentField.CheckPut(ArrayOfTables) Do
			ArrayOfTables.Delete(ArrayOfTables.Count()-1);
		EndDo;
		
		If VerticalQuantity <> ArrayOfTables.Count() Then
			MessageText = NStr("en='Maximal amount by vertical: '") + ArrayOfTables.Count();
			SmallBusinessServer.ShowMessageAboutError(ThisForm, MessageText, , , "VerticalQuantity", Error);
		EndIf;
		
	EndIf;
	
	Return Not Error;
	
EndFunction // CheckIsSomethingFitsSomewhere()

// The procedure sets the printing area in the tabular document and draws a dotted frame on side.
//
&AtServer
Procedure SetPrintAreaAtServer(AreaName)
	
	SelectedArea = SpreadsheetDocumentField.Area(AreaName);
	
	None = New Line(SpreadsheetDocumentCellLineType.None, 0);
	ThinDashed = New Line(SpreadsheetDocumentCellLineType.ThinDashed, 1);
	
	If SpreadsheetDocumentField.PrintArea <> Undefined Then
		SpreadsheetDocumentField.PrintArea.Outline(None,None,None,None);
	EndIf;
	
	SpreadsheetDocumentField.PrintArea = SelectedArea;
	SpreadsheetDocumentField.PrintArea.Outline(ThinDashed,ThinDashed,ThinDashed,ThinDashed);
	
	SpreadsheetDocumentField.PrintArea.AutoRowHeight = False;
	
EndProcedure // SetPrintArea()

// The procedure sets the printing area in the tabular document and draws a dotted frame on side.
//
&AtClient
Procedure SetPrintArea(Command)
	
	If SpreadsheetDocumentField.SelectedAreas[0].Left <> 0
		AND SpreadsheetDocumentField.SelectedAreas[0].Top <> 0
		AND TypeOf(SpreadsheetDocumentField.SelectedAreas[0]) = Type("SpreadsheetDocumentRange") Then
		
		SetPrintAreaAtServer(SpreadsheetDocumentField.SelectedAreas[0].Name);
		
	Else
		
		ClearMessages();
		Message = New UserMessage;
		Message.Text = NStr("en = 'Print area is incorrect'");
		Message.Field = "SpreadsheetDocumentField";
		Message.Message();
		
	EndIf;
	
EndProcedure // SetPrintArea()

// The procedure puts a barcode picture to the tabular document.
//
&AtServer
Procedure InsertBarcodePicture(CurrentAreaName)
	
	//receive the barcode picture from an additional layout
	TemplateForBarCode = New Picture(Catalogs.LabelsAndTagsTemplates.GetTemplate("BarCodePicture"));
	
	BarCodePicture = SpreadsheetDocumentField.Drawings.Add(SpreadsheetDocumentDrawingType.Picture);
	IndexOf = SpreadsheetDocumentField.Drawings.IndexOf(BarCodePicture);
	SpreadsheetDocumentField.Drawings[IndexOf].Picture = TemplateForBarCode;
	SpreadsheetDocumentField.Drawings[IndexOf].Name = GetParameterNameBarcode()+StrReplace(New UUID,"-","_");
	SpreadsheetDocumentField.Drawings[IndexOf].Place(SpreadsheetDocumentField.Area(CurrentAreaName));
	
EndProcedure // InsertBarcodePicture()

// The function receives a string with the barcode parameter name to pass to DLS.
//
&AtClientAtServerNoContext
Function GetParameterNameBarcode()
	
	Return "Barcode";
	
EndFunction // GetParameterNameBarcode()


&AtServer
// The procedure merges the area cells
//
// Parameters
//  AreaName  - String - The area name for merging
//
Procedure MergeArea(AreaName)
	
	Area = SpreadsheetDocumentField.Area(AreaName);
	Area.Merge();
	
EndProcedure // MergeArea()

&AtServer
// The procedure disconnects the area cells
//
// Parameters
//  AreaName  - String - The area name for merging
//
Procedure UndoMergeArea(AreaName)
	
	Area = SpreadsheetDocumentField.Area(AreaName);
	Area.UndoMerge();
	
EndProcedure // MergeArea()

// The procedure selects an available field
//
// Parameters
//  Select  - DataCompositionID - Data composition ID
//
&AtClient
Procedure ChoiceAvailableField(SelectedRow)
	
	// It is required to select the area in the tabular document before adding.
	If TypeOf(SpreadsheetDocumentField.CurrentArea) <> Type("SpreadsheetDocumentRange") Then
		ShowMessageBox(Undefined,"To transfer the template field, it is required to select a cell or cells area.");
		Return;
	Else
		CurrentArea = SpreadsheetDocumentField.CurrentArea;
		//CurrentArea.Union();
		MergeArea(CurrentArea.Name);
	EndIf;

	// Data preparation.
	FieldNameInTemplate = String(SettingsComposer.Settings.OrderAvailableFields.GetObjectByID(SelectedRow).Field);
	
	// Put a field in the template.
	If FieldNameInTemplate = GetParameterNameBarcode() Then
		
		Notification = New NotifyDescription("SelectionOfAvailableFieldCompletion",ThisForm,FieldNameInTemplate);
		ShowQueryBox(Notification,"Add the barcode as a picture?", QuestionDialogMode.YesNo);
		
	Else
		
		CurrentArea.FillType = SpreadsheetDocumentAreaFillType.Template;
		CurrentArea.Text = CurrentArea.Text + "["+FieldNameInTemplate+"]";
		
	EndIf;
	
EndProcedure // ChoiceAvailableField()

&AtClient
Procedure SelectionOfAvailableFieldCompletion(Response,FieldNameInTemplate) Export
	
	CurrentArea = SpreadsheetDocumentField.CurrentArea;
	
	If Response = DialogReturnCode.Yes Then
		InsertBarcodePicture(CurrentArea.Name);
	Else
		CurrentArea.FillType = SpreadsheetDocumentAreaFillType.Template;
		CurrentArea.Text = CurrentArea.Text + "["+FieldNameInTemplate+"]";
	EndIf;
	
EndProcedure

&AtClient
// Procedure
//
Procedure AvailableFieldsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	Modified = True;
	ChoiceAvailableField(SelectedRow);
	
EndProcedure // AvailableFieldsSelection()

// The procedure puts the default template to the tabular document.
//
&AtServer
Procedure PlaceDefaultTemplateToSpreadsheetDocument(PatternName)
	
	DefaultTemplate = Catalogs.LabelsAndTagsTemplates.GetTemplate(PatternName);
	
	SpreadsheetDocumentField = DefaultTemplate;
	
EndProcedure // PlaceDefaultTemplateToSpreadsheetDocument()

// Procedure - command handler "DefaultLabel".
//
&AtClient
Procedure DefaultLabel(Command)
	
	Notification = New NotifyDescription("DefaultTemplateCompletion",ThisForm,"DefaultLabelTemplate");
	ShowQueryBox(Notification,NStr("en = 'The edited template will be changed by the default template, continue?'"), QuestionDialogMode.YesNo);
	
EndProcedure // DefaultLabel()

// Procedure - command handler "PriceTagByDefault".
//
&AtClient
Procedure PriceTagByDefault(Command)
	
	Notification = New NotifyDescription("DefaultTemplateCompletion",ThisForm,"DefaultTagTemplate");
	ShowQueryBox(Notification,NStr("en = 'The edited template will be changed by the default template, continue?'"), QuestionDialogMode.YesNo);
	
EndProcedure // PriceTagByDefault()

&AtClient
Procedure DefaultTemplateCompletion(Result,PatternName) Export
	
	If Result = DialogReturnCode.Yes Then
		PlaceDefaultTemplateToSpreadsheetDocument(PatternName);
	EndIf;
	
EndProcedure

// Procedure - command handler "Merge".
//
&AtClient
Procedure Union(Command)
	
	If TypeOf(SpreadsheetDocumentField.SelectedAreas[0]) = Type("SpreadsheetDocumentRange") Then
		
		CurrentArea = SpreadsheetDocumentField.CurrentArea;
		MergeArea(CurrentArea.Name);
		
	Else
		
		ClearMessages();
		Message = New UserMessage;
		Message.Text = NStr("en = 'Incorrect area!'");
		Message.Field = "SpreadsheetDocumentField";
		Message.Message();
		
	EndIf;
	
EndProcedure // Union()

// Procedure - command handler "UndoMerge".
//
&AtClient
Procedure UndoMerge(Command)
	
	If TypeOf(SpreadsheetDocumentField.SelectedAreas[0]) = Type("SpreadsheetDocumentRange") Then
		
		CurrentArea = SpreadsheetDocumentField.CurrentArea;
		UndoMergeArea(CurrentArea.Name);
		
	Else
		
		ClearMessages();
		Message = New UserMessage;
		Message.Text = NStr("en = 'Incorrect area!'");
		Message.Field = "SpreadsheetDocumentField";
		Message.Message();
		
	EndIf;
	
EndProcedure // UndoMerge()

// Procedure - command handler "Choose".
//
&AtClient
Procedure Select(Command)
	
	CurrentRow = Items.AvailableFields.CurrentRow;
	If CurrentRow <> Undefined Then
		ChoiceAvailableField(CurrentRow);
	EndIf;
	
EndProcedure // Select()
