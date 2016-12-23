
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	ObjectReference = Parameters.Ref;
	
	Common_Template = InformationRegisters.ObjectsVersions.GetTemplate("StandardTemplateOfObjectPresentation");
	
	LightGrayColour = StyleColors.InaccessibleDataColor;
	RedVioletColour = StyleColors.DeletedAttributeTitleBackground;
	
	If TypeOf(Parameters.ComparedVersions) = Type("Array") Then
		// Versions numbers from the ObjectVersions
		// register for comparison or one version if a report is on one object.
		ComparedVersions = New FixedArray(SortAscending(Parameters.ComparedVersions));
		
		If ComparedVersions.Count() > 1 Then
			StringOfVersionsNumber = "";
			
			ComparedVersionsCZ = New ValueList;
			ComparedVersionsCZ.LoadValues(Parameters.ComparedVersions);
			ComparedVersionsCZ.SortByValue();
			
			For Each VersionsListItem IN ComparedVersionsCZ Do
				StringOfVersionsNumber = StringOfVersionsNumber + String(VersionsListItem.Value) + ", ";
			EndDo;
			
			StringOfVersionsNumber = Left(StringOfVersionsNumber, StrLen(StringOfVersionsNumber) - 2);
			
			Title = StringFunctionsClientServer.PlaceParametersIntoString(
			                 NStr("en='Versions comparison ""%1"" (No.No. %2)';ru='Сравнение версий ""%1"" (№№ %2)'"),
			                 CommonUse.SubjectString(ObjectReference),
			                 StringOfVersionsNumber);
		Else
			Title = StringFunctionsClientServer.PlaceParametersIntoString(
			                 NStr("en='Object version ""%1"" No.%2';ru='Версия объекта ""%1"" №%2'"),
			                 ObjectReference,
			                 String(ComparedVersions[0]));
		EndIf;
		
		GenerateReport(ReportTable, ComparedVersions);
	Else // Passed object version is used.
		SerializedObject = GetFromTempStorage(Parameters.SerializedObjectAddress);
		If Parameters.ByVersion Then // Report on one version is used.
			ReportTable = ObjectVersioning.ReportByObjectVersioning(ObjectReference, SerializedObject);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Main module function that is responsible for report generation.
// Depending on the number of versions in the array,
// it causes either the functionality of the report
// generation by one version, or the functionality of report generation by the changes between several versions.
//
&AtServer
Procedure GenerateReport(ReportTS, ComparedVersions)
	
	If ComparedVersions.Count() = 1 Then
		ReportTS = ObjectVersioning.ReportByObjectVersioning(ObjectReference, ComparedVersions[0]);
	Else
		GenerateChangesReport(ReportTS, ComparedVersions);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// The function for receiving report on changes.

// The main managing function for generating a report on changes.
// Consists of three stages:
// 1. Receive XML of the stored object versions presentation. Generate
//    special data structures for objects comparison.
// 2. Get 
//
&AtServer
Procedure GenerateChangesReport(ReportTS, Val VersionArray)
	
	// Stores transitional parsed object
	// version to reduce the number of XML parses.
	Var ObjectVersioning;
	
	// "Cross" identifier of the changed strings in versions.
	Var CounterUniqueId;
	
	ReportTS.Clear();
	
	// Generate an array of version numbers (as
	// some may not be available and have numbering), the array is sorted by ascending.
	VersionsNumbersArray = VersionArray;
	
	// Object versions quantity stored in the base (k).
	// To generate the report, it is required to make (k-1) comparisons.
	// This means that the changes table have (k) columns.
	ObjectsVersionsCount = VersionsNumbersArray.Count();
	
	// Stores all changes of attributes and has two dimensions:
	// the first one (rows) contains the
	// object attribute name values, the second one (columns)
	// contains the identification of the object version and
	// change characteristics version identification is a string that identifies the object version among the rest ones and provides additional information on the change.
	DetailsChangesTable = New ValueTable;
	PrepareColumnsOfAttributeChangesTables(DetailsChangesTable, VersionsNumbersArray);
	
	// Stores the tabular section changes as matches
	// of the object value table names of the
	// changes history in the values table each match - tabular
	// section the first one (row) contains the
	// field name values of the tabular
	// section, the second one (columns) contains the identification
	// of the object version identification is a string that identifies the object version among the rest ones and provides additional information on the change.
	ChangesTableTableParts = New Map;
	
	// Generate the initial object versions values of
	// which are always displayed (if there are subsequent changes).
	ObjectVersioning_Pre = ReadInitialAttributeValuesAndTabularSections(
	                               DetailsChangesTable,
	                               ChangesTableTableParts,
	                               ObjectsVersionsCount,
	                               VersionsNumbersArray);
	
	CounterUniqueId = GetUniqueUniqueId(ChangesTableTableParts, "Version" + Format(VersionsNumbersArray[0], "NG=0"));
	
	For VersionIndex = 2 To VersionsNumbersArray.Count() Do
		VersionNumber = VersionsNumbersArray[VersionIndex-1];
		PreviousVersionNumber = "Version" + (Format(VersionsNumbersArray[VersionIndex-2], "NG=0"));
		CurrentVersionsColumnName = "Version" + Format(VersionNumber, "NG=0");
		
		ComparisonResult = CalculateChanges(VersionNumber, ObjectVersioning_Pre, ObjectVersioning);
		
		// Fill in the report table according to the attributes.
		FillAttributeChangeCharacteristic(ComparisonResult["Attributes"]["and"],
			"AND", DetailsChangesTable, CurrentVersionsColumnName, ObjectVersioning);
		FillAttributeChangeCharacteristic(ComparisonResult["Attributes"]["d"],
			"D", DetailsChangesTable, CurrentVersionsColumnName, ObjectVersioning);
		FillAttributeChangeCharacteristic(ComparisonResult["Attributes"]["u"],
			"U", DetailsChangesTable, CurrentVersionsColumnName, ObjectVersioning);
		
		// Changes in the tabular sections.
		TabularSectionChanges = ComparisonResult["TabularSections"]["and"];
		
		// This functionality is not implemented yet.
		AddedTabularSections = ComparisonResult["TabularSections"]["d"];
		DeletedTabularSections = ComparisonResult["TabularSections"]["u"];
		
		For Each MapItem IN ObjectVersioning.TabularSections Do
			TableName = MapItem.Key;
			
			If ValueIsFilled(AddedTabularSections.Find(TableName))
			 Or ValueIsFilled(DeletedTabularSections.Find(TableName)) Then
				Continue;
			EndIf;
			
			ChangesTableTableParts[TableName][CurrentVersionsColumnName] = 
				ObjectVersioning.TabularSections[TableName].Copy();
				
			TablesVersionRef = ChangesTableTableParts[TableName][CurrentVersionsColumnName];
			TablesVersionRef.Columns.Add("RowId_Versioning");
			For Each TableRow IN TablesVersionRef Do
				TableRow.Versioning_StringId = TableRow.LineNumber;
			EndDo;
			
			TablesVersionRef.Columns.Add("Versioning_Modification");
			TablesVersionRef.FillValues(False, "Versioning_Modification");
			
			TablesVersionRef.Columns.Add("Versioning_Changes", New TypeDescription("Array"));
			
			TableWithChanges = TabularSectionChanges.Get(TableName);
			If TableWithChanges <> Undefined Then
				ModifiedRows = TableWithChanges["AND"];
				AddedStrings = TableWithChanges["D"];
				DeletedStrings = TableWithChanges["U"];
				
				LengthVTS0 = ObjectVersioning_Pre.TabularSections[TableName].Count();
				If LengthVTS0 = 0 Then
					MarkedTTNO = New Array;
				Else
					MarkedTTNO = New Array(LengthVTS0);
				EndIf;
				
				LengthTTN1 = ObjectVersioning.TabularSections[TableName].Count();
				If LengthTTN1 = 0 Then
					MarkedInTS1 = New Array;
				Else
					MarkedInTS1 = New Array(LengthTTN1);
				EndIf;
				
				For Each TSItem IN ModifiedRows Do
					RowTCH = ChangesTableTableParts[TableName][PreviousVersionNumber][TSItem.IndexTTN0-1];
					TablesVersionRef[TSItem.IndexOfTS1-1].Versioning_StringId = RowTCH.Versioning_StringId;
					TablesVersionRef[TSItem.IndexOfTS1-1].Versioning_Modification = "AND";
					TablesVersionRef[TSItem.IndexOfTS1-1].Versioning_Changes = TSItem.Differences;
				EndDo;
				
				For Each TSItem IN AddedStrings Do
					TablesVersionRef[TSItem.IndexOfTS1-1].Versioning_StringId = IncrementCounter(CounterUniqueId, TableName);
					TablesVersionRef[TSItem.IndexOfTS1-1].Versioning_Modification = "D";
				EndDo;
				
				// It is required to fill in UniqueId in all items (compare with the previous version).
				For IndexOf = 1 To TablesVersionRef.Count() Do
					If TablesVersionRef[IndexOf-1].Versioning_StringId = Undefined Then
						// String for which it is required to find match in the previous table.
						TSRow = TablesVersionRef[IndexOf-1];
						
						FilterParameters = New Structure;
						CommonColumns = FindCommonColumns(TablesVersionRef, ChangesTableTableParts[TableName][PreviousVersionNumber]);
						For Each ColumnName IN CommonColumns Do
							If (ColumnName <> "RowId_Versioning") AND (ColumnName <> "Versioning_Modification") Then
								FilterParameters.Insert(ColumnName, TSRow[ColumnName]);
							EndIf;
						EndDo;
						
						ArrayOfStringsPreviousTS = ChangesTableTableParts[TableName][PreviousVersionNumber].FindRows(FilterParameters);
						
						FilterParameters.Insert("Versioning_Modification", Undefined);
						RowArrayCurrentPM = TablesVersionRef.FindRows(FilterParameters);
						
						For IndByVT_Current = 1 To RowArrayCurrentPM.Count() Do
							If IndByVT_Current <= ArrayOfStringsPreviousTS.Count() Then
								RowArrayCurrentPM[IndByVT_Current-1].Versioning_StringId = ArrayOfStringsPreviousTS[IndByVT_Current-1].Versioning_StringId;
							EndIf;
							RowArrayCurrentPM[IndByVT_Current-1].Versioning_Modification = False;
						EndDo;
					EndIf;
				EndDo;
				For Each TSItem IN DeletedStrings Do
					VirtualRow = TablesVersionRef.Add();
					VirtualRow.Versioning_StringId = ChangesTableTableParts[TableName][PreviousVersionNumber][TSItem.IndexTTN0-1].Versioning_StringId;
					VirtualRow.Versioning_Modification = "U";
				EndDo;
			EndIf;
		EndDo;
		ObjectVersioning_Pre = ObjectVersioning;
	EndDo;
	
	// Pass linked information to a special block for data output to a report.
	OutputCompositionResultsToReport(DetailsChangesTable,
									  ChangesTableTableParts,
									  CounterUniqueId,
									  VersionsNumbersArray,
									  ReportTS);
	
	TemplateLegend = Common_Template.GetArea("Legend");
	ReportTS.Output(TemplateLegend);
	
EndProcedure

&AtServer
Procedure OutputAttributeChanges(ReportTS,
                                     DetailsChangesTable,
                                     VersionsNumbersArray)
	
	CapDetailsArea = Common_Template.GetArea("AttributesHeader");
	ReportTS.Output(CapDetailsArea);
	ReportTS.StartRowGroup("AttributesGroup");
	
	For Each ModAttributeItem IN DetailsChangesTable Do
		If ModAttributeItem.Versioning_Modification = True Then
			DescriptionAttribute = ObjectVersioning.GetAttributePresentationInLanguage(ModAttributeItem.Description);
			
			AttributeFullName = ObjectReference.Metadata().Attributes.Find(DescriptionAttribute);
			If AttributeFullName = Undefined Then
				For Each StandardAttributeDescription IN ObjectReference.Metadata().StandardAttributes Do
					If StandardAttributeDescription.Name = DescriptionAttribute Then
						AttributeFullName = StandardAttributeDescription;
						Break;
					EndIf;
				EndDo;
			EndIf;
			
			OutputDescription = DescriptionAttribute;
			If AttributeFullName <> Undefined Then
				OutputDescription = AttributeFullName.Presentation();
			EndIf;
			
			EmptyCell = Common_Template.GetArea("EmptyCell");
			ReportTS.Output(EmptyCell);;
			
			DescriptionAttribute = Common_Template.GetArea("NameFieldAttribute");
			DescriptionAttribute.Parameters.NameFieldAttribute = OutputDescription;
			ReportTS.Join(DescriptionAttribute);
			
			DetailsVersionsIndex = VersionsNumbersArray.Count();
			
			While DetailsVersionsIndex >= 1 Do
				StructureCharacteristicChanges = ModAttributeItem["Version" + Format(VersionsNumbersArray[DetailsVersionsIndex-1], "NG=0")];
				
				DetailsValuePresentation = "";
				AttributeValue = "";
				Update = Undefined;
				ValueType = "";
				
				// If the current version does not have attribute changes, then skip it to the next version.
				If TypeOf(StructureCharacteristicChanges) = Type("String") Then
					
					DetailsValuePresentation = String(AttributeValue);
					
				ElsIf StructureCharacteristicChanges <> Undefined Then
					If StructureCharacteristicChanges.ChangeType = "U" Then
					Else
						AttributeValue = StructureCharacteristicChanges.Value.AttributeValue;
						DetailsValuePresentation = String(AttributeValue);
					EndIf;
					// Receive a structure of the attribute change in the current version.
					Update = StructureCharacteristicChanges.ChangeType;
				EndIf;
				
				If DetailsValuePresentation = "" Then
					DetailsValuePresentation = AttributeValue;
					If DetailsValuePresentation = "" Then
						DetailsValuePresentation = " ";
					EndIf;
				EndIf;
				
				If      Update = Undefined Then
					DetailsValueArea = Common_Template.GetArea("InitialAttributeValue");
					DetailsValueArea.Parameters.AttributeValue = DetailsValuePresentation;
				ElsIf Update = "AND" Then
					DetailsValueArea = Common_Template.GetArea("ModifiedAttributeValue");
					DetailsValueArea.Parameters.AttributeValue = DetailsValuePresentation;
				ElsIf Update = "U" Then
					DetailsValueArea = Common_Template.GetArea("DeletedAttribute");
					DetailsValueArea.Parameters.AttributeValue = DetailsValuePresentation;
				ElsIf Update = "D" Then
					DetailsValueArea = Common_Template.GetArea("AddedAttribute");
					DetailsValueArea.Parameters.AttributeValue = DetailsValuePresentation;
				EndIf;
				
				ReportTS.Join(DetailsValueArea);
				
				DetailsVersionsIndex = DetailsVersionsIndex - 1;
			EndDo;
		EndIf;
	EndDo;
	
	ReportTS.EndRowGroup();
	
EndProcedure

&AtServer
Procedure OutputChangesTableSections(ReportTS,
                                          ChangesTableTableParts,
                                          VersionsNumbersArray,
                                          CounterUniqueId)
	
	ServiceColumnPrefix = "Versioning_";
	TablePartsSectionTitleShow = False;
	
	FreeLineTemplate = Common_Template.GetArea("FreeLine");
	NextLineTPTemplate = Common_Template.GetArea("CapLineTablePortion");
	
	ReportTS.Output(FreeLineTemplate);
	
	// cycle by all changed ones 
	For Each ChangedTPItem IN ChangesTableTableParts Do
		TabularSectionName = ChangedTPItem.Key;
		CurrentTSVersions = ChangedTPItem.Value;
		
		CurrentTabularSectionChanged = False;
		
		For TechCounterUniqueId = 1 To CounterUniqueId[TabularSectionName] Do
			
			StringUniqueIdChanged = False;
			// IN case a change is found, it is required to
			// show the original version from which the changes are executed.
			BasicVersionFilled = False;
			
			// Search by all change versions by the current string (UniqueId
			// = CurrCounterUniqueId) if the string is removed, you can abort the search
			// and go to the next string preliminary highlighting "deleted" with a color of a remote entity.
			VersionsIndex = VersionsNumbersArray.Count();
			
			// ---------------------------------------------------------------------------------
			// preview version to make sure that the changes occur---
			
			ModifiedRows = False;
			
			While VersionsIndex >= 1 Do
				CurrentTSColumnVersions = "Version" + Format(VersionsNumbersArray[VersionsIndex-1], "NG=0");
				CurrentVersionOfTS = CurrentTSVersions[CurrentTSColumnVersions];
				
				FoundString = Undefined;
				If CurrentVersionOfTS.Columns.Find("RowId_Versioning") <> Undefined Then
					FoundString = CurrentVersionOfTS.Find(TechCounterUniqueId, "RowId_Versioning");
				EndIf;
				
				If FoundString <> Undefined Then
					If (FoundString.Versioning_Modification <> Undefined) Then
						If (TypeOf(FoundString.Versioning_Modification) = Type("String")
							OR (TypeOf(FoundString.Versioning_Modification) = Type("Boolean")
							      AND FoundString.Versioning_Modification = True)) Then
							ModifiedRows = True;
						EndIf;
					EndIf;
				EndIf;
				VersionsIndex = VersionsIndex - 1;
			EndDo;
			
			If Not ModifiedRows Then
				Continue;
			EndIf;
			
			// ---------------------------------------------------------------------------------
			
			// Display the versions to the tabular document.
			VersionsIndex = VersionsNumbersArray.Count();
			
			IntervalBetweenFills = 0;
			
			// Cycle by all versions. Try to find changes by string in
			// each version by its UniqueId.
			While VersionsIndex >= 1 Do
				IntervalBetweenFills = IntervalBetweenFills + 1;
				CurrentTSColumnVersions = "Version" + Format(VersionsNumbersArray[VersionsIndex-1]);
				// Tabular section of the current version (values table with the modification flag).
				CurrentVersionOfTS = CurrentTSVersions[CurrentTSColumnVersions];
				FoundString = CurrentVersionOfTS.Find(TechCounterUniqueId, "RowId_Versioning");
				
				// String change is found in the next version (it may be the first change from the end).
				If FoundString <> Undefined Then
					
					// Block for section header output of all tabular sections.
					If Not TablePartsSectionTitleShow Then
						TablePartsSectionTitleShow = True;
						CommonPatternOfHeaderSectionOfPM = Common_Template.GetArea("CapTableParts");
						ReportTS.Output(CommonPatternOfHeaderSectionOfPM);
						ReportTS.StartRowGroup("GroupTableParts");
						ReportTS.Output(FreeLineTemplate);
					EndIf;
					
					// Block for header output of the current processed tabular section.
					If Not CurrentTabularSectionChanged Then
						CurrentTabularSectionChanged = True;
						CurrentTSCapTemplate = Common_Template.GetArea("CapTablePortion");
						CurrentTSCapTemplate.Parameters.TabularSectionDescription = TabularSectionName;
						ReportTS.Output(CurrentTSCapTemplate);
						ReportTS.StartRowGroup("TabularSection"+TabularSectionName);
						ReportTS.Output(FreeLineTemplate);
					EndIf;
					
					Modification = FoundString.Versioning_Modification;
					
					If StringUniqueIdChanged = False Then
						StringUniqueIdChanged = True;
						
						CapTSRowsTemplate = Common_Template.GetArea("CapLineTablePortion");
						CapTSRowsTemplate.Parameters.TabularSectionLineNumber = TechCounterUniqueId;
						ReportTS.Output(CapTSRowsTemplate);
						ReportTS.StartRowGroup("GroupRows"+TabularSectionName+TechCounterUniqueId);
						
						OutputType = "";
						If Modification = "U" Then
							OutputType = "U"
						EndIf;
						ArrayFill = New Array;
						For Each Column IN CurrentVersionOfTS.Columns Do
							If Find(Column.Name, ServiceColumnPrefix) = 1 Then
								Continue;
							EndIf;
							ArrayFill.Add(Column.Name);
						EndDo;
						
						EmptySector = GenerateEmptySector(CurrentVersionOfTS.Columns.Count()-2);
						FillingEmptySector = GenerateEmptySector(CurrentVersionOfTS.Columns.Count()-2, OutputType);
						Section = GenerateTSRowSector(ArrayFill, OutputType);
						
						ReportTS.Join(EmptySector);
						ReportTS.Join(Section);
					EndIf;
					
					While IntervalBetweenFills > 1 Do
						ReportTS.Join(FillingEmptySector);
						IntervalBetweenFills = IntervalBetweenFills - 1;
					EndDo;
					
					IntervalBetweenFills = 0;
					
					// Now fill in the next changed table row.
					ArrayFill = New ValueList;
					For Each Column IN CurrentVersionOfTS.Columns Do
						If Find(Column.Name, ServiceColumnPrefix) = 1 Then
							Continue;
						EndIf;
						
						Presentation = String(FoundString[Column.Name]);
						ArrayFill.Add(FoundString["Versioning_Changes"].Find(Column.Name) <> Undefined, Presentation);
					EndDo;
					
					If TypeOf(Modification) = Type("Boolean") Then
						OutputType = "";
					Else
						OutputType = Modification;
					EndIf;
					
					Section = GenerateTSRowSector(ArrayFill, OutputType);
					ReportTS.Join(Section);
				EndIf;
				VersionsIndex = VersionsIndex - 1;
			EndDo;
			
			If StringUniqueIdChanged Then
				ReportTS.EndRowGroup();
				ReportTS.Output(FreeLineTemplate);
			EndIf;
			
		EndDo;
		
		If CurrentTabularSectionChanged Then
			ReportTS.EndRowGroup();
			ReportTS.Output(FreeLineTemplate);
		EndIf;
		
	EndDo;
	
	If TablePartsSectionTitleShow Then
		ReportTS.EndRowGroup();
		ReportTS.Output(FreeLineTemplate);
	EndIf;
	
EndProcedure

&AtServer
Function OutputCompositionResultsToReport(DetailsChangesTable,
                                          ChangesTableTableParts,
                                          CounterUniqueId,
                                          VersionsNumbersArray,
                                          ReportTS)
	
	ChangedDetailsNumber = CalculateQuantityOfChangedAttributes(DetailsChangesTable, VersionsNumbersArray);
	NumberOfVersions = VersionsNumbersArray.Count();
	
	///////////////////////////////////////////////////////////////////////////////
	//                           OUTPUT REPORT                                   //
	///////////////////////////////////////////////////////////////////////////////
	
	ReportTS.Clear();
	
	OutputHeader(ReportTS, VersionsNumbersArray, NumberOfVersions);
	
	If ChangedDetailsNumber = 0 Then
		CapDetailsArea = Common_Template.GetArea("AttributesHeader");
		ReportTS.Output(CapDetailsArea);
		ReportTS.StartRowGroup("AttributesGroup");
		DetailsAreaNotChanged = Common_Template.GetArea("AttributesAreNotChanged");
		ReportTS.Output(DetailsAreaNotChanged);
		ReportTS.EndRowGroup();
	Else
		OutputAttributeChanges(ReportTS,
		                           DetailsChangesTable,
		                           VersionsNumbersArray);
		
	EndIf;
	
	OutputChangesTableSections(ReportTS,
	                                ChangesTableTableParts,
	                                VersionsNumbersArray,
	                                CounterUniqueId);
	
	ReportTS.TotalsBelow = False;
	ReportTS.ShowGrid = False;
	ReportTS.Protection = False;
	ReportTS.ReadOnly = True;
	
EndFunction

&AtServer
Function OutputHeader(ReportTS, VersionsNumbersArray, NumberOfVersions)
	
	AreaHeader = Common_Template.GetArea("Header");
	AreaHeader.Parameters.ReportDescription = NStr("en=""Report by Changes of the Object's Versions"";ru='Отчет по изменениям версий объекта'");
	AreaHeader.Parameters.ObjectDescription = String(ObjectReference);
	
	ReportTS.Output(AreaHeader);
	
	EmptyCell = Common_Template.GetArea("EmptyCell");
	VersionArea = Common_Template.GetArea("TitleVersion");
	ReportTS.Join(EmptyCell);
	ReportTS.Join(VersionArea);
	VersionArea = Common_Template.GetArea("ViewVersion");
	
	CommentToVersions = New Structure;
	AreComments = False;
	
	VersionsIndex = NumberOfVersions;
	While VersionsIndex > 0 Do
		
		InfoAboutVersions = GetDescriptionByVersion(VersionsNumbersArray[VersionsIndex-1]);
		VersionArea.Parameters.ViewVersion = InfoAboutVersions.Definition;
		
		CommentToVersions.Insert("Comment" + VersionsIndex, InfoAboutVersions.Comment);
		If Not IsBlankString(InfoAboutVersions.Comment) Then
			AreComments = True;
		EndIf;
		
		ReportTS.Join(VersionArea);
		ReportTS.Area("C"+String(VersionsIndex+2)).ColumnWidth = 50;
		VersionsIndex = VersionsIndex - 1;
		
	EndDo;
	
	If AreComments Then
		
		CommentArea = Common_Template.GetArea("TitleComment");
		ReportTS.Output(EmptyCell);
		ReportTS.Join(CommentArea);
		CommentArea = Common_Template.GetArea("Comment");
		
		VersionsIndex = NumberOfVersions;
		While VersionsIndex > 0 Do
			
			CommentArea.Parameters.Comment = CommentToVersions["Comment" + VersionsIndex];
			ReportTS.Join(CommentArea);
			VersionsIndex = VersionsIndex - 1;
			
		EndDo;
		
	EndIf;
	
	FreeLineArea = Common_Template.GetArea("FreeLine");
	ReportTS.Output(FreeLineArea);
	
EndFunction

// Report engine. Fill in the report by the passed version number.
// The versions of the VersionParsingResult_0 passed as
// a parameter and one specified by VersionNumber are compared.
// Execution sequence:
// 1. Receive the result of compared object versions parsing.
// 2. Generate the list of attributes and tabular sections that were
//    - changed
//    - added
//    - deleted.
//
&AtServer
Function CalculateChanges(VersionNumber,
                           VersionParsingResult_0,
                           VersionParsingResult_1)
	
	ThisIsDocument = False;
	
	If Metadata.Documents.Contains(ObjectReference.Metadata()) Then
		ThisIsDocument = True;
	EndIf;
	
	// Parse the second to last version.
	Attributes_0      = VersionParsingResult_0.Attributes;
	TabularSections_0 = VersionParsingResult_0.TabularSections;
	
	// Parse the latest version.
	VersionParsingResult_1 = ObjectVersioning.VersionParsing(ObjectReference, VersionNumber);
	AddLineNumbersInTabularSections(VersionParsingResult_1.TabularSections);
	
	Attributes_1      = VersionParsingResult_1.Attributes;
	TabularSections_1 = VersionParsingResult_1.TabularSections;
	
	///////////////////////////////////////////////////////////////////////////////
	//           Generate tabular sections list that were changed           
	/////////////////////////////////////////////////////////////////////////////////
	TabularSectionsList_0	= CreateComparisonTable();
	For Each Item IN TabularSections_0 Do
		NewRow = TabularSectionsList_0.Add();
		NewRow.Set(0, TrimAll(Item.Key));
	EndDo;
	
	TabularSectionsList_1	= CreateComparisonTable();
	For Each Item IN TabularSections_1 Do
		NewRow = TabularSectionsList_1.Add();
		NewRow.Set(0, TrimAll(Item.Key));
	EndDo;
	
	// The metadata structure may have been changed. - attributes were added or deleted.
	AddedTSList = SubtractTable(TabularSectionsList_1, TabularSectionsList_0);
	DeletedTSList  = SubtractTable(TabularSectionsList_0, TabularSectionsList_1);
	
	// The list of not changed attributes according to which you should search for matches / variance.
	RemainingTSList = SubtractTable(TabularSectionsList_1, AddedTSList);
	
	// List of the attributes that were changed.
	ChangedTSList = FindChangedTabularSections(RemainingTSList,
	                                                       TabularSections_0,
	                                                       TabularSections_1);
	
	///////////////////////////////////////////////////////////////////////////////
	//           Generate the list of the attributes that were changed           //      
	///////////////////////////////////////////////////////////////////////////////
	DetailsList0 = CreateComparisonTable();
	For Each Attribute IN VersionParsingResult_0.Attributes Do
		NewRow = DetailsList0.Add();		
		NewRow.Set(0, TrimAll(String(Attribute.DescriptionAttribute)));
	EndDo;
	
	DetailsList1 = CreateComparisonTable();
	For Each Attribute IN VersionParsingResult_1.Attributes Do
		NewRow = DetailsList1.Add();
		NewRow.Set(0, TrimAll(String(Attribute.DescriptionAttribute)));
	EndDo;
	
	// The metadata structure may have been changed. - attributes were added or deleted.
	AddedDetailsList = SubtractTable(DetailsList1, DetailsList0);
	DeletedDetailsList  = SubtractTable(DetailsList0, DetailsList1);
	
	// The list of not changed attributes according to which you should search for matches / variance.
	RemainingDetailsList = SubtractTable(DetailsList1, AddedDetailsList);
	
	// List of the attributes that were changed.
	ChangedDetailsList = CreateComparisonTable();
	
	ChangesInDetails = New Map;
	ChangesInDetails.Insert("d", AddedDetailsList);
	ChangesInDetails.Insert("u", DeletedDetailsList);
	ChangesInDetails.Insert("and", ChangedDetailsList);
	
	For Each ValueTableRow IN RemainingDetailsList Do
		
		Attribute = ValueTableRow.Value;
		Value_0 = Attributes_0.Find(Attribute, "DescriptionAttribute").AttributeValue;
		Value_1 = Attributes_1.Find(Attribute, "DescriptionAttribute").AttributeValue;
		
		If TypeOf(Value_0) <> Type("ValueStorage")
			AND TypeOf(Value_1) <> Type("ValueStorage") Then
			If Value_0 <> Value_1 Then
				NewRow = ChangedDetailsList.Add();
				NewRow.Set(0, Attribute);
			EndIf;
		EndIf;
		
	EndDo;
	
	ChangesInTables = CalculateChangesOfTabularSections(
	                              ChangedTSList,
	                              TabularSections_0,
	                              TabularSections_1);
	
	ModificationTableParts = New Structure;
	ModificationTableParts.Insert("d", AddedTSList);
	ModificationTableParts.Insert("u", DeletedTSList);
	ModificationTableParts.Insert("and", ChangesInTables);
	
	CompositionChanges = New Map;
	CompositionChanges.Insert("Attributes",      ChangesInDetails);
	CompositionChanges.Insert("TabularSections", ModificationTableParts);
	
	Return CompositionChanges;
	
EndFunction

// The function adds columns corresponding to the object versions quantity.
// Columns are named as "Version<Number>", where
// <Number> is from 1 to the saved object versions quantity. Numbering
// is conditional i.e. for example, the "Version1" name
// may not correspond to the saved version of the object with the version 0.
//
&AtServer
Procedure PrepareColumnsOfAttributeChangesTables(ValueTable,
                                                      VersionsNumbersArray)
	
	ValueTable = New ValueTable;
	
	ValueTable.Columns.Add("Description");
	ValueTable.Columns.Add("Versioning_Modification");
	ValueTable.Columns.Add("Versioning_TypeValues"); // Estimated value type.
	
	For IndexOf = 1 To VersionsNumbersArray.Count() Do
		ValueTable.Columns.Add("Version" + Format(VersionsNumbersArray[IndexOf-1], "NG=0"));
	EndDo;
	
EndProcedure

&AtServer
Function CalculateChangesOfTabularSections(ChangedTSList,
                                          TabularSections_0,
                                          TabularSections_1)
	
	ChangesInTables = New Map;
	
	// Cycle by the tabular sections quantity.
	For IndexOf = 1 To ChangedTSList.Count() Do
		
		ChangesInTables.Insert(ChangedTSList[IndexOf-1].Value, New Map);
		
		TableForAnalysis = ChangedTSList[IndexOf-1].Value;
		TS0 = TabularSections_0[TableForAnalysis];
		PM1 = TabularSections_1[TableForAnalysis];
		
		TableModifiedRows = New ValueTable;
		TableModifiedRows.Columns.Add("IndexTTN0");
		TableModifiedRows.Columns.Add("IndexOfTS1");
		TableModifiedRows.Columns.Add("Differences");
		
		MapTheRowsOfTS0RowsamTS1 = FindSimilarRowsOfTables(TS0, PM1);
		AccordanceRowsTS1ToRowsTS0 = New Map;
		CheckedColumns = FindCommonColumns(TS0, PM1);
		For Each Map IN MapTheRowsOfTS0RowsamTS1 Do
			TableRow0 = Map.Key;
			TableString1 = Map.Value;
			StringDifferences = StringDifferences(TableRow0, TableString1, CheckedColumns);
			If StringDifferences.Count() > 0 Then
				NewRow = TableModifiedRows.Add();
				NewRow["IndexTTN0"] = RowIndex(TableRow0) + 1;
				NewRow["IndexOfTS1"] = RowIndex(TableString1) + 1;
				NewRow["Differences"] = StringDifferences;
			EndIf;
			AccordanceRowsTS1ToRowsTS0.Insert(TableString1, TableRow0);
		EndDo;
		
		TableAddedRows = New ValueTable;
		TableAddedRows.Columns.Add("IndexOfTS1");
		
		For Each TableRow IN PM1 Do
			If AccordanceRowsTS1ToRowsTS0[TableRow] = Undefined Then
				NewRow = TableAddedRows.Add();
				NewRow.IndexOfTS1 = PM1.IndexOf(TableRow) + 1;
			EndIf;
		EndDo;
		
		TableDeletedRows = New ValueTable;
		TableDeletedRows.Columns.Add("IndexTTN0");
		
		For Each TableRow IN TS0 Do
			If MapTheRowsOfTS0RowsamTS1[TableRow] = Undefined Then
				NewRow = TableDeletedRows.Add();
				NewRow.IndexTTN0 = TS0.IndexOf(TableRow) + 1;
			EndIf;
		EndDo;
		
		ChangesInTables[ChangedTSList[IndexOf-1].Value].Insert("D", TableAddedRows);
		ChangesInTables[ChangedTSList[IndexOf-1].Value].Insert("U", TableDeletedRows);
		ChangesInTables[ChangedTSList[IndexOf-1].Value].Insert("AND", TableModifiedRows);
		
	EndDo;
	
	Return ChangesInTables;
	
EndFunction

// Compares two tabular sections the list of which
// is passed to the first parameter and tries to find the differences in them (not matching items). If
// there are such tables, then the list of such tabular sections is generated.
//
&AtServer
Function FindChangedTabularSections(RemainingTSList,
                                        TabularSections_0,
                                        TabularSections_1)
	
	ChangedTSList = CreateComparisonTable();
	
	// Search for Tabular sections in which the rows are changed.
	For Each Item IN RemainingTSList Do
		
		CWT_0 = TabularSections_0[Item.Value];
		CWT_1 = TabularSections_1[Item.Value];
		
		If CWT_0.Count() = CWT_1.Count() Then
			
			FoundDifference = False;
			
			// Check whether columns structure remained the same (is equivalent).
			If TSEquivalents (CWT_0.Columns, CWT_1.Columns) Then
				
				// Search for different items - of a string.
				For IndexOf = 0 To CWT_0.Count() - 1 Do
					String_0 = CWT_0[IndexOf];
					String_1 = CWT_1[IndexOf];
					
					If Not RowsOfTSAreEqual(String_0, String_1, CWT_0.Columns) Then
						FoundDifference = True;
						Break;
					EndIf
				EndDo;
				
			Else
				FoundDifference = True;
			EndIf;
			
			If FoundDifference Then
				NewRow = ChangedTSList.Add();
				NewRow.Set(0, Item.Value);
			EndIf;
			
		Else
			NewRow = ChangedTSList.Add();
			NewRow.Set(0, Item.Value);
		EndIf;
			
	EndDo;
	
	Return ChangedTSList;
	
EndFunction

// The function reads the initial attribute values and
// document tabular sections format of the generated data structure for the attributes:
// AttributesTable - ValuesTable
// Columns 
// |-Version<junior
// version number> |-...
// |-Version<senior
// version number>
// |-Versioning_Modification (Boolean) |-Name
//
// The strings contain a list of attributes and their changes over
// time, the Versioning_Modification column contains a string modification flag:
// FALSE - String was
// not changed "d"  - String
// was added "u"  - String
// was deleted "i"  - String was changed.
//
// Format of the generated data structure for the value tables:
// TableOfPM - Map
// |- <Tabular section name1> - Map
//    |-Version<junior version number> - ValuesTable
//       Columns
//       |- Basic columns of the object
//       part corresponding table |- Versioning_StringId     - unique, within the table, ID
//       of the current string |- Versioning_Modification  - a string
//           modification flag takes the following values:
//           FALSE - String was
//           not changed "d"  - String
//           was added "u"  - String
//           was deleted "i"  - String was changed.
//    |-...
//    |-Version<senior
// version number> |-...
// |- <Tabular section nameN>
//
&AtServer
Function ReadInitialAttributeValuesAndTabularSections(AttributesTable,
                                                           TableOfPM,
                                                           CountVersions,
                                                           VersionsNumbersArray)
	
	MinObjectVersioning = VersionsNumbersArray[0];
	
	// Parse the first version.
	ObjectVersioning  = ObjectVersioning.VersionParsing(ObjectReference, MinObjectVersioning);
	AddLineNumbersInTabularSections(ObjectVersioning.TabularSections);
	
	Attributes      = ObjectVersioning.Attributes;
	TabularSections = ObjectVersioning.TabularSections;
	
	Column = "Version" + Format(VersionsNumbersArray[0], "NG=0");
	
	For Each ValueTableRow IN Attributes Do
		
		NewRow = AttributesTable.Add();
		NewRow[Column] = New Structure("ChangeType, Value", "AND", ValueTableRow);
		NewRow.Description = ValueTableRow.DescriptionAttribute;
		NewRow.Versioning_Modification = False;
		NewRow.Versioning_ValueType = ValueTableRow.AttributeType;
		
	EndDo;
	
	For Each TSItem IN TabularSections Do
		
		TableOfPM.Insert(TSItem.Key, New Map);
		PrepareColumnsOfChangesTablesForMap(TableOfPM[TSItem.Key], VersionsNumbersArray);
		TableOfPM[TSItem.Key]["Version" + Format(MinObjectVersioning, "NG=0")] = TSItem.Value.Copy();
		
		CurrentTV = TableOfPM[TSItem.Key]["Version" + Format(MinObjectVersioning, "NG=0")];
		
		// Special string identifier to
		// distinguish strings the value is unique within this values table.
		
		CurrentTV.Columns.Add("RowId_Versioning");
		CurrentTV.Columns.Add("Versioning_Modification");
		CurrentTV.Columns.Add("Versioning_Changes", New TypeDescription("Array"));
		
		For IndexOf = 1 To CurrentTV.Count() Do
			CurrentTV[IndexOf-1].Versioning_StringId = IndexOf;
			CurrentTV[IndexOf-1].Versioning_Modification = False;
		EndDo;
	
	EndDo;
	
	Return ObjectVersioning;
	
EndFunction

&AtServer
Procedure PrepareColumnsOfChangesTablesForMap(Map, VersionsNumbersArray)
	
	Quantity = VersionsNumbersArray.Count();
	
	For IndexOf = 1 To Quantity Do
		Map.Insert("Version" + Format(VersionsNumbersArray[IndexOf-1], "NG=0"), New ValueTable);
	EndDo;
	
EndProcedure

// Returns True or False depending on whether tabular
// sections are equivalent or not. TS are equivalent if the
// quantity, name and type of their fields are the same. Changing the columns order is
// not considered to be a change of the tabular section.
//
&AtServer
Function TSEquivalents(FirstTableColumns, ColumnsOfSecondTables)
	If FirstTableColumns.Count() <> ColumnsOfSecondTables.Count() Then
		Return False;
	EndIf;
	
	For Each Column IN FirstTableColumns Do
		Found = ColumnsOfSecondTables.Find(Column.Name);
		If Found = Undefined Or Column.ValueType <> Found.ValueType Then
			Return False;
		EndIf;
	EndDo;
	
	Return True;
EndFunction

// The function compares values of two strings (by value) and returns them.
// True if the strings are equal, otherwise, returns False.
// It is assumed that the structure of the tabular section metadata is equivalent.
//
&AtServer
Function RowsOfTSAreEqual(StringPm1, StringTS2, Columns)
	
	For Each Column IN Columns Do
		ColumnName = Column.Name;
		If StringTS2.Owner().Columns.Find(ColumnName) = Undefined Then
			Continue;
		EndIf;
		ValueOfTS1 = StringPm1[ColumnName];
		ValueOfTS2 = StringTS2[ColumnName];
		If ValueOfTS1 <> ValueOfTS2 Then
			Return False;
		EndIf;
	EndDo;
	
	Return True;
	
EndFunction

// Receives a description of the stored object version as a string.
//
&AtServer
Function GetDescriptionByVersion(VersionNumber)
	
	InfoAboutVersions = ObjectVersioning.InfoAboutObjectVersion(ObjectReference, VersionNumber);
	Definition = StringFunctionsClientServer.PlaceParametersIntoString(NStr("en='No. %1 / (%2) / %3';ru='№ %1 / (%2) / %3'"), 
		VersionNumber, String(InfoAboutVersions.VersionDate), TrimAll(String(InfoAboutVersions.VersionAuthor)));
	InfoAboutVersions.Insert("Definition", Definition);
	
	Return InfoAboutVersions;
	
EndFunction

// Calculates the quantity of the changed attributes in the table of the changed attributes.
//
&AtServer
Function CalculateQuantityOfChangedAttributes(DetailsChangesTable, VersionsNumbersArray)
	
	Result = 0;
	
	For Each ItemTV IN DetailsChangesTable Do
		If ItemTV.Versioning_Modification <> Undefined AND ItemTV.Versioning_Modification = True Then
			Result = Result + 1;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

// It increases the value of the cross-counter for a table.
//
&AtServer
Function IncrementCounter(CounterUniqueId, TableName);
	
	CounterUniqueId[TableName] = CounterUniqueId[TableName] + 1;
	
	Return CounterUniqueId[TableName];
	
EndFunction

// Returns the unique number to identify a row from a table by version.
//
&AtServer
Function GetUniqueUniqueId(ChangesTableOfTS, ColumnNameVersions)
	
	MapUniqueId = New Map;
	
	For Each ItemMp IN ChangesTableOfTS Do
		MapUniqueId[ItemMp.Key] = Number(ItemMp.Value[ColumnNameVersions].Count());
	EndDo;
	
	Return MapUniqueId;
	
EndFunction

// Fills in the table of report on the comparison results at a certain step.
//
// Parameters:
// MarkingChanges - String - "d" - attribute
//                             is added "u" - attribute
//                             is deleted "i" - attribute is changed.
//
&AtServer
Procedure FillAttributeChangeCharacteristic(DetailChangesTable, 
                                                    MarkingChanges,
                                                    DetailsChangesTable,
                                                    CurrentVersionsColumnName,
                                                    ObjectVersioning)
	
	For Each Item IN DetailChangesTable Do
		Description = Item.Value;
		UpdateAttribute = DetailsChangesTable.Find (Description, "Description");
		
		If UpdateAttribute = Undefined Then
			UpdateAttribute = DetailsChangesTable.Add();
			UpdateAttribute.Description = Description;
		EndIf;
		
		ChangingParameters = New Structure;
		ChangingParameters.Insert("ChangeType", MarkingChanges);
		
		If MarkingChanges = "u" Then
			ChangingParameters.Insert("Value", "Deleted");
		Else
			ChangingParameters.Insert("Value", ObjectVersioning.Attributes.Find(Description, "DescriptionAttribute"));
		EndIf;
		
		UpdateAttribute[CurrentVersionsColumnName] = ChangingParameters;
		UpdateAttribute.Versioning_Modification = True;
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Other service procedures and functions.

// FillValue - array of rows.
// OutputType - String :
//           "and" - changing
//           "d" - addition
//           "u" - deletion
//           ""  - common terminal
&AtServer
Function GenerateTSRowSector(Val FillingValues, Val OutputType = "")
	
	SpreadsheetDocument = New SpreadsheetDocument;
	
	If      OutputType = ""  Then
		Pattern = Common_Template.GetArea("InitialAttributeValue");
	ElsIf OutputType = "AND" Then
		Pattern = Common_Template.GetArea("ModifiedAttributeValue");
	ElsIf OutputType = "D" Then
		Pattern = Common_Template.GetArea("AddedAttribute");
	ElsIf OutputType = "U" Then
		Pattern = Common_Template.GetArea("DeletedAttribute");
	EndIf;
	
	PatternNoChange = Common_Template.GetArea("InitialAttributeValue");
	PatternHasChange = Common_Template.GetArea("ModifiedAttributeValue");
	
	HasDetail = TypeOf(FillingValues) = Type("ValueList");
	For Each Item IN FillingValues Do
		Value = Item;
		If HasDetail Then
			Value = Item.Presentation;
			HasChange = Item.Value;
			Pattern = ?(HasChange, PatternHasChange, PatternNoChange);
		EndIf;
		Pattern.Parameters.AttributeValue = Value;
		SpreadsheetDocument.Put(Pattern);
	EndDo;
	
	Return SpreadsheetDocument;
	
EndFunction

// Creates an empty sector for output into report. Used
// if the string was not changed in one of the versions.
//
&AtServer
Function GenerateEmptySector(Val RowCount, Val OutputType = "")
	
	FillValue = New Array;
	
	For IndexOf = 1 To RowCount Do
		FillValue.Add(" ");
	EndDo;
	
	Return GenerateTSRowSector(FillValue, OutputType);
	
EndFunction

// The function returns the result of the table range items subtraction.
// DeductedTable from MainTable.
//
&AtServer
Function SubtractTable(Val MainTable,
                       Val TableOfDeduction,
                       Val ColumnCompareMainTable = "",
                       Val CompareColumnSubstractTable = "")
	
	If Not ValueIsFilled(ColumnCompareMainTable) Then
		ColumnCompareMainTable = "Value";
	EndIf;
	
	If Not ValueIsFilled(CompareColumnSubstractTable) Then
		CompareColumnSubstractTable = "Value";
	EndIf;
	
	ResultTable = New ValueTable;
	ResultTable = MainTable.Copy();
	
	For Each Item IN TableOfDeduction Do
		Value = Item[ColumnCompareMainTable];
		FoundString = ResultTable.Find(Value, ColumnCompareMainTable);
		If FoundString <> Undefined Then
			ResultTable.Delete(FoundString);
		EndIf;
	EndDo;
	
	Return ResultTable;
	
EndFunction

// The function returns the table created based on InitializationTable.
// If InitializationTable is not specified, then an empty table is created.
//
&AtServer
Function CreateComparisonTable(TableInitialization = Undefined,
                                ColumnNameCompare = "Value")
	
	Table = New ValueTable;
	Table.Columns.Add(ColumnNameCompare);
	
	If TableInitialization <> Undefined Then
		
		ValueArray = TableInitialization.UnloadColumn(ColumnNameCompare);
		
		For Each Item IN TableInitialization Do
			NewRow = Table.Add();
			NewRow.Set(0, Item[ColumnNameCompare]);
		EndDo;
		
	EndIf;
	
	Return Table;

EndFunction

&AtServer
Function SortAscending(Val Array)
	ValueList = New ValueList;
	ValueList.LoadValues(Array);
	ValueList.SortByValue(SortDirection.Asc);
	Return ValueList.UnloadValues();
EndFunction

&AtServer
Function RowIndex(TableRow)
	Return TableRow.Owner().IndexOf(TableRow);
EndFunction

&AtServer
Procedure AddLineNumbersInTabularSections(TabularSections)
	
	For Each Map IN TabularSections Do
		Table = Map.Value;
		If Table.Columns.Find("LineNumber") <> Undefined Then
			Continue;
		EndIf;
		Table.Columns.Insert(0, "LineNumber",,NStr("en='No. rows';ru='№ строки'"));
		For LineNumber = 1 To Table.Count() Do
			Table[LineNumber-1].LineNumber = LineNumber;
		EndDo;
	EndDo;
	
EndProcedure

// Algorithm of tables comparison

// Compares strings of the custom tables by values considering the column name matches. Returns strings match.
// Table1 to Table2 strings. Strings a match for which is not found are not included in the result. Match
// is set between the "similar" strings, i.e. the strings where there is at least one values match.
// While comparing values in the strings, values collections are compared by the references (they are not compared by the collection items).
//
// Parameters:
//  Table1, Table2 - ValueTable - compared tables.
//
// Service parameters:
//  RequiredDifferencesCount - Number - differences quantity that should be between the strings (strictly).
//  MaxDiff - Number - limits the RequiredDifferencesQuantity parameter increment during the recursive call.
//  MapRowsOfTables1Tables2Rowsam - Map - already found strings match.
//
// Returns:
//  Map - Strings match where keys - Tables1 rows, values - Tables2 rows.
//
// Use:
//
//    StringsMatch = FindSimilarTableStrings (Table1, Table2);
//
// Note:
//  Service parameters are used during the recursive call, it is not recommended to specify them while calling the function.
//  To search for the strings with the exact number of differences, use the same values for parameters.
//  RequiredDifferencesQuantity and MaxDifferences.
//  For example if you want to find 100% similar strings, the call will be as such:
//
//    StringsMatch = FindSimilarTableStrings (Table1, Table2, 0, 0);
//
&AtServer
Function FindSimilarRowsOfTables(Table1, Table2, Val RequiredDifferencesCount = 0, Val MaxDiff = Undefined, MapRowsOfTables1Tables2Rowsam = Undefined)
	
	If MapRowsOfTables1Tables2Rowsam = Undefined Then
		MapRowsOfTables1Tables2Rowsam = New Map;
	EndIf;
	
	If MaxDiff = Undefined Then
		MaxDiff = MaximumCountOfDifferencesBetweenRowsInTables(Table1, Table2);
	EndIf;
	
	// Calculate the backward correspondence for a quick search by value.
	AccordanceRowsOfTable2ToRowsOfTable1 = New Map; // Keys - table rows2, values = table rows1.
	For Each Item IN MapRowsOfTables1Tables2Rowsam Do
		AccordanceRowsOfTable2ToRowsOfTable1.Insert(Item.Value, Item.Key);
	EndDo;
	
	// Compare each string to each string.
	For Each TableString1 IN Table1 Do
		For Each TableRow2 IN Table2 Do
			If MapRowsOfTables1Tables2Rowsam[TableString1] = Undefined 
			   AND AccordanceRowsOfTable2ToRowsOfTable1[TableRow2] = Undefined Then // Skip found strings.
			
				// consider differences
				CountDifferences = DifferencesInTableRowsCount(TableString1, TableRow2);
				
				// Analyze the strings comparison result.
				If CountDifferences = RequiredDifferencesCount Then
					MapRowsOfTables1Tables2Rowsam.Insert(TableString1, TableRow2);
					AccordanceRowsOfTable2ToRowsOfTable1.Insert(TableRow2, TableString1);
					Break;
				EndIf;
				
			EndIf;
		EndDo;
	EndDo;
	
	If RequiredDifferencesCount < MaxDiff Then
		FindSimilarRowsOfTables(Table1, Table2, RequiredDifferencesCount + 1, MaxDiff, MapRowsOfTables1Tables2Rowsam);
	EndIf;
	
	Return MapRowsOfTables1Tables2Rowsam;
	
EndFunction

&AtServer
Function MaximumCountOfDifferencesBetweenRowsInTables(Table1, Table2)
	
	ArrayColumnNamesTables1 = GetColumnNames(Table1);
	NameArrayColumnsTables2 = GetColumnNames(Table2);
	ArrayOfNamesForColumnsInBothTables = SetsUnion(ArrayColumnNamesTables1, NameArrayColumnsTables2);
	TotalColumns = ArrayOfNamesForColumnsInBothTables.Count();
	
	Return ?(TotalColumns = 0, 0, TotalColumns - 1);

EndFunction

&AtServer
Function SetsUnion(Lot1, SetOf2)
	
	Result = New Array;
	
	For Each Item IN Lot1 Do
		IndexOf = Result.Find(Item);
		If IndexOf = Undefined Then
			Result.Add(Item);
		EndIf;
	EndDo;
	
	For Each Item IN SetOf2 Do
		IndexOf = Result.Find(Item);
		If IndexOf = Undefined Then
			Result.Add(Item);
		EndIf;
	EndDo;	
	
	Return Result;
	
EndFunction

&AtServer
Function GetColumnNames(Table)
	
	Result = New Array;
	
	For Each Column IN Table.Columns Do
		Result.Add(Column.Name);
	EndDo;
	
	Return Result;
	
EndFunction

&AtServer
Function DifferencesInTableRowsCount(TableString1, TableRow2)
	
	Result = 0;
	
	Table1 = TableString1.Owner();
	Table2 = TableRow2.Owner();
	
	CommonColumns = FindCommonColumns(Table1, Table2);
	RestColumns = FindMismatchedColumns(Table1, Table2);
	
	// Each column that is not a general one consider as one difference.
	Result = Result + RestColumns.Count();
	
	// Calculate differences by the unmatched values.
	For Each ColumnName IN CommonColumns Do
		If TableString1[ColumnName] <> TableRow2[ColumnName] Then
			Result = Result + 1;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

&AtServer
Function FindCommonColumns(Table1, Table2)
	NameArray1 = GetColumnNames(Table1);
	NameArray2 = GetColumnNames(Table2);
	Return SetsIntersection(NameArray1, NameArray2);
EndFunction

&AtServer
Function FindMismatchedColumns(Table1, Table2)
	NameArray1 = GetColumnNames(Table1);
	NameArray2 = GetColumnNames(Table2);
	Return DifferenceOfVarieties(NameArray1, NameArray2, True);
EndFunction

&AtServer
Function DifferenceOfVarieties(Lot1, Val SetOf2, SymmetricDifference = False)
	
	Result = New Array;
	SetOf2 = CopyArray(SetOf2);
	
	For Each Item IN Lot1 Do
		IndexOf = SetOf2.Find(Item);
		If IndexOf = Undefined Then
			Result.Add(Item);
		Else
			SetOf2.Delete(IndexOf);
		EndIf;
	EndDo;
	
	If SymmetricDifference Then
		For Each Item IN SetOf2 Do
			Result.Add(Item);
		EndDo;
	EndIf;
	
	Return Result;
EndFunction

&AtServer
Function SetsIntersection(Lot1, SetOf2)
	
	Result = New Array;
	
	For Each Item IN Lot1 Do
		IndexOf = SetOf2.Find(Item);
		If IndexOf <> Undefined Then
			Result.Add(Item);
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

&AtServer
Function CopyArray(Array)
	
	Result = New Array;
	
	For Each Item IN Array Do
		Result.Add(Item);
	EndDo;
	
	Return Result;
	
EndFunction

&AtServer
Function StringDifferences(Row1, Row2, CheckedColumns)
	Result = New Array;
	For Each Column IN CheckedColumns Do
		If TypeOf(Row1[Column]) = Type("ValueStorage") Then
			Continue; // Do not compare the attributes with the StorageValues type.
		EndIf;
		If Row1[Column] <> Row2[Column] Then
			Result.Add(Column);
		EndIf;
	EndDo;
	Return Result;
EndFunction

#EndRegion













