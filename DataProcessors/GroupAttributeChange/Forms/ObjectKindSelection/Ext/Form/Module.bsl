#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	CollectionsOfMetadataObjects = New Array;
	CollectionsOfMetadataObjects.Add(Metadata.Catalogs);
	CollectionsOfMetadataObjects.Add(Metadata.Documents);
	CollectionsOfMetadataObjects.Add(Metadata.BusinessProcesses);
	CollectionsOfMetadataObjects.Add(Metadata.Tasks);
	CollectionsOfMetadataObjects.Add(Metadata.ChartsOfCalculationTypes);
	CollectionsOfMetadataObjects.Add(Metadata.ChartsOfCharacteristicTypes);
	CollectionsOfMetadataObjects.Add(Metadata.ChartsOfAccounts);
	CollectionsOfMetadataObjects.Add(Metadata.ExchangePlans);
	
	RemovedObjectPrefix = "Delete";
	
	If SSLVersionMeetsRequirements() Then
		ObjectManagers = ObjectManagersForEditingDetails();
	EndIf;
	
	For Each MetadataObjectCollection IN CollectionsOfMetadataObjects Do
		For Each MetadataObject IN MetadataObjectCollection Do
			If Not Parameters.ShowHidden Then
				If Lower(Left(MetadataObject.Name, StrLen(RemovedObjectPrefix))) = Lower(RemovedObjectPrefix)
					Or ItIsServiceObject(MetadataObject, ObjectManagers) Then
					Continue;
				EndIf;
			EndIf;
			If AccessRight("Update", MetadataObject) Then
				AvailableObjectsForChange.Add(MetadataObject.FullName(), MetadataObject.Synonym);
			EndIf;
		EndDo;
	EndDo;
	AvailableObjectsForChange.SortByPresentation();
	
	If Not IsBlankString(Parameters.CurrentObject) Then
		Items.AvailableObjectsForChange.CurrentRow = AvailableObjectsForChange.FindByValue(Parameters.CurrentObject).GetID();
	EndIf;
EndProcedure

&AtClient
Procedure AvailableObjectsForChangeSelection(Item, SelectedRow, Field, StandardProcessing)
	StandardProcessing = False;
	Close(Items.AvailableObjectsForChange.CurrentData.Value);
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Select(Command)
	CurrentData = Items.AvailableObjectsForChange.CurrentData;
	If CurrentData <> Undefined Then
		Close(CurrentData.Value);
	EndIf;
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServerNoContext
Function ItIsServiceObject(MetadataObject, ObjectManagers)
	
	If ObjectManagers <> Undefined Then
		AvailableMethods = ObjectManagerMethodsForEditingDetails(MetadataObject.FullName(), ObjectManagers);
		If TypeOf(AvailableMethods) = Type("Array") AND (AvailableMethods.Count() = 0 OR 
			AvailableMethods.Find("EditedAttributesInGroupDataProcessing") <> Undefined) Then
			
			ObjectManager = ObjectManagerByFullName(MetadataObject.FullName());
			editable = ObjectManager.EditedAttributesInGroupDataProcessing();
		EndIf;
		
	Else
		// For configurations without SSL or SSL in old versions try to determine whether there are editable attributes of the object.
		ObjectManager = ObjectManagerByFullName(MetadataObject.FullName());
		Try
			editable = ObjectManager.EditedAttributesInGroupDataProcessing();
		Except
			// method is not found
			editable = Undefined;
		EndTry;
	EndIf;
	
	If editable <> Undefined AND editable.Count() = 0 Then
		Return True;
	EndIf;
	
	//
	
	If ObjectManagers <> Undefined Then
		If TypeOf(AvailableMethods) = Type("Array") AND (AvailableMethods.Count() = 0 OR 
			AvailableMethods.Find("NotEditableInGroupProcessingAttributes") <> Undefined) Then
			
			If ObjectManager = Undefined Then
				ObjectManager = ObjectManagerByFullName(MetadataObject.FullName());
			EndIf;	
			NotEditable = ObjectManager.NotEditableInGroupProcessingAttributes();
		EndIf;
		
	Else
		// For configurations without SSL or SSL in old versions try to determine whether there are noneditable attributes of the object.
		Try
			NotEditable = ObjectManager.NotEditableInGroupProcessingAttributes();
		Except
			// method is not found
			NotEditable = Undefined;
		EndTry;
	EndIf;
	
	If NotEditable <> Undefined AND NotEditable.Find("*") <> Undefined Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

&AtServerNoContext
Function ObjectManagerMethodsForEditingDetails(ObjectName, ObjectManagers)
	
	ObjectManagerInfo = ObjectManagers[ObjectName];
	If ObjectManagerInfo = Undefined Then
		Return "NotSupported";
	EndIf;
	AvailableMethods = DecomposeStringIntoSubstringsArray(ObjectManagerInfo, Chars.LF, True);
	Return AvailableMethods;
	
EndFunction

&AtServerNoContext
Function ObjectManagersForEditingDetails()
	
	ModuleStandardSubsystemIntegration = CommonModule("StandardSubsystemsIntegration");
	ModuleGroupObjectChangeOverridable = CommonModule("GroupObjectChangeOverridable");
	If ModuleStandardSubsystemIntegration = Undefined Or ModuleGroupObjectChangeOverridable = Undefined Then
		Return New Array;
	EndIf;
	
	ObjectsWithLockedDetails = New Map;
	ModuleStandardSubsystemIntegration.WhenDefiningObjectsWithEditableAttributes(ObjectsWithLockedDetails);
	ModuleGroupObjectChangeOverridable.WhenDefiningObjectsWithEditableAttributes(ObjectsWithLockedDetails);
	
	Return ObjectsWithLockedDetails;
	
EndFunction

&AtServerNoContext
Function SSLVersionMeetsRequirements()
	
	Try
		ModuleStandardSubsystemsServer = CommonModule("StandardSubsystemsServer");
	Except
		// Module does not exist
		ModuleStandardSubsystemsServer = Undefined;
	EndTry;
	If ModuleStandardSubsystemsServer = Undefined Then 
		Return False;
	EndIf;
	
	SSLVersion = ModuleStandardSubsystemsServer.LibraryVersion();
	Return VersionNumberToNumber(SSLVersion) >= VersionNumberToNumber("2.2.4.9");
	
EndFunction

&AtServerNoContext
Function VersionNumberToNumber(VersionNumber)
	NumberParts = DecomposeStringIntoSubstringsArray(VersionNumber, ".", True);
	If NumberParts.Count() <> 4 Then
		Return 0;
	EndIf;
	Result = 0;
	For Each NumberPart IN NumberParts Do
		Result = Result * 1000 + Number(NumberPart);
	EndDo;
	Return Result;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedure and function of basic functionality to ensure independence.

&AtServerNoContext
Function ObjectManagerByFullName(DescriptionFull)
	Var MOClass, MOName, Manager;
	
	NameParts = DecomposeStringIntoSubstringsArray(DescriptionFull, ".");
	
	If NameParts.Count() = 2 Then
		MOClass = NameParts[0];
		MOName  = NameParts[1];
	EndIf;
	
	If      Upper(MOClass) = "EXCHANGEPLAN" Then
		Manager = ExchangePlans;
		
	ElsIf Upper(MOClass) = "CATALOG" Then
		Manager = Catalogs;
		
	ElsIf Upper(MOClass) = "DOCUMENT" Then
		Manager = Documents;
		
	ElsIf Upper(MOClass) = "DOCUMENTJOURNAL" Then
		Manager = DocumentJournals;
		
	ElsIf Upper(MOClass) = "ENUM" Then
		Manager = Enums;
		
	ElsIf Upper(MOClass) = "REPORT" Then
		Manager = Reports;
		
	ElsIf Upper(MOClass) = "DATAPROCESSOR" Then
		Manager = DataProcessors;
		
	ElsIf Upper(MOClass) = "CHARTOFCHARACTERISTICTYPES" Then
		Manager = ChartsOfCharacteristicTypes;
		
	ElsIf Upper(MOClass) = "CHARTOFACCOUNTS" Then
		Manager = ChartsOfAccounts;
		
	ElsIf Upper(MOClass) = "CHARTOFCALCULATIONTYPES" Then
		Manager = ChartsOfCalculationTypes;
		
	ElsIf Upper(MOClass) = "INFORMATIONREGISTER" Then
		Manager = InformationRegisters;
		
	ElsIf Upper(MOClass) = "ACCUMULATIONREGISTER" Then
		Manager = AccumulationRegisters;
		
	ElsIf Upper(MOClass) = "ACCOUNTINGREGISTER" Then
		Manager = AccountingRegisters;
		
	ElsIf Upper(MOClass) = "CALCULATIONREGISTER" Then
		If NameParts.Count() = 2 Then
			// Calculation register
			Manager = CalculationRegisters;
		Else
			ClassSubordinateOM = NameParts[2];
			NameOfSlave = NameParts[3];
			If Upper(ClassSubordinateOM) = "Recalculation" Then
				// Recalculation
				Manager = CalculationRegisters[MOName].Recalculations;
			Else
				Raise PlaceParametersIntoString(
					NStr("en='Unknown type of metadata object ""%1""';ru='Неизвестный тип объекта метаданных ""%1""'"), DescriptionFull);
			EndIf;
		EndIf;
		
	ElsIf Upper(MOClass) = "BUSINESSPROCESS" Then
		Manager = BusinessProcesses;
		
	ElsIf Upper(MOClass) = "TASK" Then
		Manager = Tasks;
		
	ElsIf Upper(MOClass) = "Constant" Then
		Manager = Constants;
		
	ElsIf Upper(MOClass) = "Sequence" Then
		Manager = Sequences;
	EndIf;
	
	If Manager <> Undefined Then
		Try
			Return Manager[MOName];
		Except
			Manager = Undefined;
		EndTry;
	EndIf;
	
	Raise PlaceParametersIntoString(
		NStr("en='Unknown type of metadata object ""%1""';ru='Неизвестный тип объекта метаданных ""%1""'"), DescriptionFull);
	
EndFunction

// It splits a line into several lines according to a delimiter. Delimiter may have any length.
//
// Parameters:
//  String           - String - Text with delimiters;
//  Delimiter        - String - Delimiter of text lines, minimum 1 symbol;
//  SkipBlankStrings - Boolean - flag of necessity to show empty lines in the result.
//    If the parameter is not specified, the function works in the mode of compatibility with its previous version:
//     - for delimiter-space empty lines are not included in the result, for other delimiters empty lines are included in the result.
//     E if Line parameter does not contain significant characters or doesn't contain any symbol (empty line),
//       then for delimiter-space the function result is an array containing one value ""
//       (empty line) and for other delimiters the function result is the empty array.
//
//
// Returns:
//  Array - array of rows.
//
// Examples:
//  DecomposeStringIntoSubstringsArray(",one,,two,", ",") - it will return the array of 5 elements three of which  - empty
//  lines;
//  DecomposeStringIntoSubstringsArray(",one,,two,", ",", True) - it will return an array of two items;
//  DecomposeStringIntoSubstringArray("one two ", " ") - it will return an array of two items;
//  DecomposeStringIntoSubstringArray("") - It returns an empty array;
//  DecomposeStringIntoSubstringsArray("",,False) - It returns an array with one element "" (empty line);
//  DecomposeStringIntoSubstringsArray("", " ") - It returns an array with one element "" (empty line);
//
&AtClientAtServerNoContext
Function DecomposeStringIntoSubstringsArray(Val String, Val Delimiter = ",", Val SkipBlankStrings = Undefined)
	
	Result = New Array;
	
	// To ensure backward compatibility.
	If SkipBlankStrings = Undefined Then
		SkipBlankStrings = ?(Delimiter = " ", True, False);
		If IsBlankString(String) Then 
			If Delimiter = " " Then
				Result.Add("");
			EndIf;
			Return Result;
		EndIf;
	EndIf;
	//
	
	Position = Find(String, Delimiter);
	While Position > 0 Do
		Substring = Left(String, Position - 1);
		If Not SkipBlankStrings Or Not IsBlankString(Substring) Then
			Result.Add(Substring);
		EndIf;
		String = Mid(String, Position + StrLen(Delimiter));
		Position = Find(String, Delimiter);
	EndDo;
	
	If Not SkipBlankStrings Or Not IsBlankString(String) Then
		Result.Add(String);
	EndIf;
	
	Return Result;
	
EndFunction 

// It substitutes the parameters into the string. 
// Parameters in the line are specified as %<parameter number>. Parameter numbering starts with one.
//
// Parameters:
//  LookupString  - String - Line template with parameters (inclusions of "%ParameterName" type);
//  Parameter<n>  - String - substituted parameter.
//
// Returns:
//  String   - text string with substituted parameters.
//
// Example:
//  PlaceParametersIntoString(NStr("en='%1 went to %2';ru='%1 пошел в %2'"), "John", "Zoo") = "John went to the Zoo".
//
&AtClientAtServerNoContext
Function PlaceParametersIntoString(Val LookupString,
	Val Parameter1, Val Parameter2 = Undefined, Val Parameter3 = Undefined)
	
	UseAlternativeAlgorithm = 
		Find(Parameter1, "%")
		Or Find(Parameter2, "%")
		Or Find(Parameter3, "%");
		
	If UseAlternativeAlgorithm Then
		LookupString = SubstituteParametersInStringAlternateAlgorithm(LookupString, Parameter1,
			Parameter2, Parameter3);
	Else
		LookupString = StrReplace(LookupString, "%1", Parameter1);
		LookupString = StrReplace(LookupString, "%2", Parameter2);
		LookupString = StrReplace(LookupString, "%3", Parameter3);
	EndIf;
	
	Return LookupString;
EndFunction

// It inserts parameters into the string taking into account that you can use substitution words %1, %2, etc. in the parameters
&AtClientAtServerNoContext
Function SubstituteParametersInStringAlternateAlgorithm(Val LookupString,
	Val Parameter1, Val Parameter2 = Undefined, Val Parameter3 = Undefined)
	
	Result = "";
	Position = Find(LookupString, "%");
	While Position > 0 Do 
		Result = Result + Left(LookupString, Position - 1);
		CharAfterPercent = Mid(LookupString, Position + 1, 1);
		SetParameter = "";
		If CharAfterPercent = "1" Then
			SetParameter =  Parameter1;
		ElsIf CharAfterPercent = "2" Then
			SetParameter =  Parameter2;
		ElsIf CharAfterPercent = "3" Then
			SetParameter =  Parameter3;
		EndIf;
		If SetParameter = "" Then
			Result = Result + "%";
			LookupString = Mid(LookupString, Position + 1);
		Else
			Result = Result + SetParameter;
			LookupString = Mid(LookupString, Position + 2);
		EndIf;
		Position = Find(LookupString, "%");
	EndDo;
	Result = Result + LookupString;
	
	Return Result;
EndFunction

// It returns a reference to the common module by name.
//
// Parameters:
//  Name          - String - common module name, for example:
//                  "CommonUse",
//                  "CommonUseClient".
//
// Return value:
//  CommonModule.
//
&AtClientAtServerNoContext
Function CommonModule(Name)
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	If Metadata.CommonModules.Find(Name) <> Undefined Then
		Module = Eval(Name);
	Else
		Module = Undefined;
	EndIf;
	
	If TypeOf(Module) <> Type("CommonModule") Then
		Raise PlaceParametersIntoString(
			NStr("en='Common module ""%1"" is not found.';ru='Общий модуль ""%1"" не найден.'"), Name);
	EndIf;
#Else
	Module = Eval(Name);
#If Not WebClient Then
	If TypeOf(Module) <> Type("CommonModule") Then
		Raise PlaceParametersIntoString(
			NStr("en='Common module ""%1"" is not found.';ru='Общий модуль ""%1"" не найден.'"), Name);
	EndIf;
#EndIf
#EndIf
	
	Return Module;
	
EndFunction

&AtServerNoContext
Function NamesSubordinateSubsystems(ParentSubsystem)
	
	names = New Map;
	
	For Each CurrentSubsystem IN ParentSubsystem.Subsystems Do
		
		names.Insert(CurrentSubsystem.Name, True);
		NamesOfSubordinate = NamesSubordinateSubsystems(CurrentSubsystem);
		
		For Each NameSubordinate IN NamesOfSubordinate Do
			names.Insert(CurrentSubsystem.Name + "." + NameSubordinate.Key, True);
		EndDo;
	EndDo;
	
	Return names;
	
EndFunction

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
