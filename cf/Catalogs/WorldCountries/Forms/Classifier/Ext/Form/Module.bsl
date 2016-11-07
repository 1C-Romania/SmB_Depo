
#Region FormEventsHandlers
//

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Parameters.Property("WindowOpeningMode") Then
		WindowOpeningMode = Parameters.WindowOpeningMode
	EndIf;
	
	Parameters.Property("ChoiceMode", ChoiceMode);
	Items.Classifier.ChoiceMode = ChoiceMode;
	
	// Service attributes
	ClassifierFields = "Code, Description, DescriptionFull, AlphaCode2, AlphaCode3";
	
	Meta = Metadata.Catalogs.WorldCountries;
	ClassifierObjectPresentation = Meta.ExtendedObjectPresentation;
	If IsBlankString(ClassifierObjectPresentation) Then
		ClassifierObjectPresentation = Meta.ObjectPresentation;
	EndIf;
	If IsBlankString(ClassifierObjectPresentation) Then
		ClassifierObjectPresentation = Meta.Presentation();
	EndIf;
	If Not IsBlankString(ClassifierObjectPresentation) Then
		ClassifierObjectPresentation = " (" + ClassifierObjectPresentation + ")";
	EndIf;
	
	ClassifierData = ClassifierCondition();
	Classifier.Load(ClassifierData);
	
	Filter = Classifier.FindRows(New Structure("Code", Parameters.CurrentRow.Code));
	If Filter.Count()>0 Then
		Items.Classifier.CurrentRow = Filter[0].GetID();
	EndIf;
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersClassifier
//

&AtClient
Procedure ClassifierSelection(Item, SelectedRow, Field, StandardProcessing)
	StandardProcessing = False;
	
	If Not ChoiceMode Then 
		OpenFormElementClassifier(Item.CurrentData);
		Return;
	EndIf;
	
	If TypeOf(SelectedRow)=Type("Array") Then
		SelectionStringID = SelectedRow[0];
	Else
		SelectionStringID = SelectedRow;
	EndIf;
	
	NotifyAboutClassifierElementSelection(SelectionStringID);
EndProcedure

&AtClient
Procedure ClassifierValueSelection(Item, Value, StandardProcessing)
	NotifyAboutClassifierElementSelection(Value);
EndProcedure

&AtClient
Procedure ClassifierBeforeStartAdding(Item, Cancel, Copy, Parent, Group)
	Cancel = True;
EndProcedure

&AtClient
Procedure ClassifierBeforeDelete(Item, Cancel)
	Cancel = True;
EndProcedure

&AtClient
Procedure ClassifierBeforeChange(Item, Cancel)
	Cancel = True;
	OpenFormElementClassifier(Items.Classifier.CurrentData);
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions
//

&AtClient
Procedure OpenFormElementClassifier(FillingData, IsNew=False)
	If FillingData=Undefined Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("Basis", New Structure(ClassifierFields));
	FillPropertyValues(FormParameters.Basis, FillingData);
	If IsNew Then
		FormParameters.Basis.Insert("Code", "--");
	Else
		FormParameters.Insert("ReadOnly", True);
	EndIf;
	Form = OpenForm("Catalog.WorldCountries.ObjectForm", FormParameters, Items.Classifier);
	If Not IsNew AND Form.AutoTitle Then 
		Form.AutoTitle = False;
		Form.Title = FillingData.Description + ClassifierObjectPresentation;
	EndIf;
EndProcedure

&AtClient
Procedure NotifyAboutClassifierElementSelection(SelectionStringID)
	AllStringData = Classifier.FindByID(SelectionStringID);
	If AllStringData<>Undefined Then
		RowData = New Structure(ClassifierFields);
		FillPropertyValues(RowData, AllStringData);
		
		ChoiceData = ChoiceDataElementClassifier(RowData);
		If ChoiceData.IsNew Then
			NewElementsCreatiopPublicize(ChoiceData.Ref);
		EndIf;
		
		NotifyChoice(ChoiceData.Ref);
	EndIf;
EndProcedure

&AtServerNoContext
Function ChoiceDataElementClassifier(Val CountryInformation)
	// We are searching by code only, as all codes are specified in the classifier.
	Ref = Catalogs.WorldCountries.FindByCode(CountryInformation.Code);
	IsNew = Not ValueIsFilled(Ref);
	If IsNew Then
		Country = Catalogs.WorldCountries.CreateItem();
		FillPropertyValues(Country, CountryInformation);
		Country.Write();
		Ref = Country.Ref;
	EndIf;
	
	Return New Structure("Ref, IsNew, Code", Ref, IsNew, CountryInformation.Code);
EndFunction

&AtServerNoContext
Function ClassifierCondition()
	Data = Catalogs.WorldCountries.ClassifierTable();
	
	Data.Columns.Add("IconIndex", New TypeDescription("Number", New NumberQualifiers(2, 0)));
	Data.FillValues(8, "IconIndex");
	
	Query = New Query("SELECT Code FROM Catalog.WorldCountries WHERE Predefined");
	For Each PredefinedString IN Query.Execute().Unload() Do
		DataRow = Data.Find(PredefinedString.Code, "Code");
		If DataRow<>Undefined Then
			DataRow.IconIndex = 5;
		EndIf;
	EndDo;
	
	Return Data;
EndFunction

&AtClient
Procedure NewElementsCreatiopPublicize(Ref)
	NotifyWritingNew(Ref);
	Notify("Catalog.WorldCountries.Update", Ref, ThisObject);
EndProcedure

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
