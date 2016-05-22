
#Region FormEventsHandlers
//

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Initialize the internal flags.
	CanAddToCatalog = Catalogs.WorldCountries.IsRightToAdd();
	
	If Parameters.AllowClassifierData=Undefined Then
		AllowClassifierData = True;
	Else
		BooleanType = New TypeDescription("Boolean");
		AllowClassifierData = BooleanType.AdjustValue(Parameters.AllowClassifierData);
	EndIf;
	
	OnlyClassifierData = Parameters.OnlyClassifierData;
	
	Parameters.Property("ChoiceMode", ChoiceMode);
	
	// Allow items
	Items.List.ChoiceMode = ChoiceMode;
	Items.ListChoose.Visible         = ChoiceMode;
	Items.ListChoose.DefaultButton = ChoiceMode;
	
	Items.ListChooseFromClassifier.Visible = (ChoiceMode AND Not OnlyClassifierData);
	Items.ClassifierList.Visible           = CanAddToCatalog;
	
	// Define mode by flags
	If ChoiceMode Then
		If AllowClassifierData Then
			If OnlyClassifierData Then
				If CanAddToCatalog Then 
					// Selection of classifier countries only.
					OpenClassifierForm = True
					
				Else
					// Show only catalog and classifier intersection.
					SetInterceptionFilterToClassifier();
					// Hide classifier buttons.
					Items.ListChooseFromClassifier.Visible = False;
					Items.ClassifierList.Visible           = False;
				EndIf;
				
			Else
				If CanAddToCatalog Then 
					// Show catalog and selection button from classifier (default settings).
				Else
					// Hide classifier buttons.
					Items.ListChooseFromClassifier.Visible = False;
					Items.ClassifierList.Visible           = False;
				EndIf;
			EndIf;
			
		 Else
			// Show only catalog items.
			Items.ClassifierList.Visible = False;
			// Hide classifier buttons.
			Items.ListChooseFromClassifier.Visible = False;
			Items.ClassifierList.Visible           = False;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If OpenClassifierForm Then
		// Selection only classifier countries, open its choice form.
		OpenParameters = New Structure;
		OpenParameters.Insert("ChoiceMode",        True);
		OpenParameters.Insert("CloseOnChoice", CloseOnChoice);
		OpenParameters.Insert("CurrentRow",      Items.List.CurrentRow);
		OpenParameters.Insert("WindowOpeningMode",  WindowOpeningMode);
		OpenParameters.Insert("CurrentRow",      Items.List.CurrentRow);
		
		OpenForm("Catalog.WorldCountries.Form.Classifier", OpenParameters, FormOwner);
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName="Catalog.WorldCountries.Update" Then
		RefreshListOfCountriesRepresentationList();
	EndIf;
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersList
//

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	If Not Copy Then
		Cancel = True;
		QuestionText = NStr("en='There is option to select the world country from the classifier.
		                        |Select?'");
								
		NotificationHandler = New NotifyDescription("NotificationPickQueryFromClassifier", ThisObject);
		SelectionButtons = New ValueList();
		SelectionButtons.Add(DialogReturnCode.Yes, "Pick");
		SelectionButtons.Add(DialogReturnCode.No, "Create");
		SelectionButtons.Add(DialogReturnCode.Cancel, "Cancel");
		ShowQueryBox(NotificationHandler, QuestionText, SelectionButtons, , DialogReturnCode.Cancel);
	EndIf;
EndProcedure

&AtClient
Procedure ListChoiceProcessing(Item, ValueSelected, StandardProcessing)
	If ChoiceMode Then
		// Selection from classifier
		NotifyChoice(ValueSelected);
	EndIf;
EndProcedure

&AtClient
Procedure ListNewWriteProcessing(NewObject, Source, StandardProcessing)
	RefreshListOfCountriesRepresentationList();
EndProcedure

#EndRegion

#Region FormCommandsHandlers
//

&AtClient
Procedure OpenClassifier(Command)
	// Open on view
	OpenParameters = New Structure;
	OpenParameters.Insert("CurrentRow", Items.List.CurrentRow);
	OpenForm("Catalog.WorldCountries.Form.Classifier", OpenParameters, Items.List);
EndProcedure

&AtClient
Procedure ChooseFromClassifier(Command)
	// Open for selection
	OpenParameters = New Structure;
	OpenParameters.Insert("ChoiceMode", True);
	OpenParameters.Insert("CloseOnChoice", CloseOnChoice);
	OpenParameters.Insert("CurrentRow", Items.List.CurrentRow);
	OpenParameters.Insert("WindowOpeningMode", WindowOpeningMode);
	OpenParameters.Insert("CurrentRow", Items.List.CurrentRow);
	OpenForm("Catalog.WorldCountries.Form.Classifier", OpenParameters, Items.List);
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions
//

&AtClient
Procedure RefreshListOfCountriesRepresentationList()
	
	If ItemIdentificatorFilterReferences<>Undefined Then
		// Additional filter which is to be updated was applied.
		SetInterceptionFilterToClassifier();
	EndIf;
	
	Items.List.Refresh();
EndProcedure

&AtServer
Procedure SetInterceptionFilterToClassifier()
	FilterList = List.SettingsComposer.FixedSettings.Filter;
	
	If ItemIdentificatorFilterReferences=Undefined Then
		FilterItem = FilterList.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		FilterItem.LeftValue    = New DataCompositionField("Ref");
		FilterItem.ComparisonType     = DataCompositionComparisonType.InList;
		FilterItem.Use    = True;
		
		ItemIdentificatorFilterReferences = FilterList.GetIDByObject(FilterItem);
	Else
		FilterItem = FilterList.GetObjectByID(ItemIdentificatorFilterReferences);
	EndIf;
	
	Query = New Query("
		|SELECT
		|	Code, Description
		|INTO
		|	Classifier
		|FROM
		|	&Classifier AS Classifier
		|INDEX BY
		|	Code, Description
		|;////////////////////////////////////////////////////////////
		|SELECT 
		|	Ref
		|FROM
		|	Catalog.WorldCountries AS WorldCountries
		|INNER JOIN
		|	Classifier AS Classifier
		|ON
		|	WorldCountries.Code = Classifier.Code
		|	AND WorldCountries.Description = Classifier.Description
		|");
	Query.SetParameter("Classifier", Catalogs.WorldCountries.ClassifierTable());
	FilterItem.RightValue = Query.Execute().Unload().UnloadColumn("Ref");
EndProcedure

&AtClient
Procedure NotificationPickQueryFromClassifier(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult=DialogReturnCode.Yes Then
		// Pick from ACC
		OpenParameters = New Structure;
		OpenParameters.Insert("ChoiceMode", True);
		OpenForm("Catalog.WorldCountries.Form.Classifier", OpenParameters, Items.List);
		
	ElsIf QuestionResult=DialogReturnCode.No Then
		// Adding new item
		OpenForm("Catalog.WorldCountries.ObjectForm");
		
	EndIf;
	
EndProcedure

#EndRegion
