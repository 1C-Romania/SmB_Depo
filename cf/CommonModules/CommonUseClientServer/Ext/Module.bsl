////////////////////////////////////////////////////////////////////////////////
// The subsystem "Basic functionality".
// Client and server procedures and functions of common purpose:
// - for printing forms generation support;
// - for work with files;
// - for work with managed forms; 
// - for work with mailing addresses;
// - for work with dynamic lists filters;
// - miscellaneous.
//
////////////////////////////////////////////////////////////////////////////////

#Region ApplicationInterface

// Generates and outputs the message that can be connected to form managing item.
//
//  Parameters
//  MessageTextToUser - String - message type.
//  DataKey                 - AnyRef - to infobase object.
//                               Ref to object of the infobase to which
//                               this message relates or the record key.
//  Field                       - String - form attribute name.
//  DataPath                - String - path to data (path to form attribute).
//  Cancel                      - Boolean - Output parameter.
//                               Always set to True value.
//
// Example:
//
// 1. For the message output of the managed form field connected to the object attribute.:
// CommonUseClientServer.MessageToUser(
// 	NStr("en='Message about error.';ru='Сообщение об ошибке.'"), ,
// 	"FieldInFormAttributeObject",
// 	"Object");
//
// Alternative usage variant in the form of object:
// CommonUseClientServer.MessageToUser(
// 	NStr("en='Message about error.';ru='Сообщение об ошибке.'"), ,
// 	"Object.FieldInFormAttributeObject");
//
// 2. For the message output next to the managed form field connected to the form attribute:
// CommonUseClientServer.MessageToUser(
// 	NStr("en='Message about error.';ru='Сообщение об ошибке.'"), ,
// 	"FormAttributeName");
//
// 3. For output messages connected From object infobases.
// CommonUseClientServer.MessageToUser(
// 	NStr("en='Message about error.';ru='Сообщение об ошибке.'"), InfobaseObject, "Responsible",,Cancel);
//
// 4. For output messages to link on object infobases.
// CommonUseClientServer.MessageToUser(
// 	NStr("en='Message about error.';ru='Сообщение об ошибке.'"), Refs, , , Cancel);
//
// Cases of incorrect usage:
//  1. Simultaneously pass the DataKey and DataPath parameters.
//  2. Transfer the parameter values in the DataKey type other than valid.
//  3. Set reference without setting field (and/or data path).
//
Procedure MessageToUser(
		Val MessageToUserText,
		Val DataKey = Undefined,
		Val Field = "",
		Val DataPath = "",
		Cancel = False) Export
	
	Message = New UserMessage;
	Message.Text = MessageToUserText;
	Message.Field = Field;
	
	IsObject = False;
	
#If Not ThinClient AND Not WebClient Then
	If DataKey <> Undefined
	   AND XMLTypeOf(DataKey) <> Undefined Then
		ValueTypeAsString = XMLTypeOf(DataKey).TypeName;
		IsObject = Find(ValueTypeAsString, "Object.") > 0;
	EndIf;
#EndIf
	
	If IsObject Then
		Message.SetData(DataKey);
	Else
		Message.DataKey = DataKey;
	EndIf;
	
	If Not IsBlankString(DataPath) Then
		Message.DataPath = DataPath;
	EndIf;
		
	Message.Message();
	
	Cancel = True;
	
EndProcedure

// Adds a user's new error to the errors
// list for the further sending using the TellUserAboutErrors() procedure.
//  Used in procedures FillCheckProcessing.
//
// Parameters:
//  Errors          - Undefined - new list will be created,
//                  - Value set during the first call of this procedure with the Undefined value.
//
//  ErrorField      - String - value that is specified in the Object field in the UserMessage property.
//                    It should contain %1 for auto input of the row number.
//                    For example, "Object.TIN" or "Object.Users[%1].User".
//
//  SingleErrorText - String - text Errors for case, When ErrorsGroup in collections only One,
//                    for example, NStr("en='User is not selected.';ru='Пользователь не выбран.'").
//
//  ErrorsGroup    - Arbitrary - used to select either text for
//                    one mistake, or text for multiple errors, for example, the Object name.Users".
//                    It the value is not filled in, the text for one error is used.
//
//  LineNumber     - Number - value from 0 ... , defining the row number that
//                    should be input to the ErrorField row and to the TextForSeveralErrors text (input LineNumber +1).
//
//  SeveralErrorText - String - text Errors for case, When added some errors From similar
//                    property ErrorsGroup, for example, NStr("en='User in the row %1 is not selected.';ru='Пользователь в строке %1 не выбран.'").
//
//  RowIndex    - Undefined - matches the LineNumber parameter value.
//                    Number - value from 0 ... , specifying the row number that
//                    should be input to the ErrorField row.
//
Procedure AddUserError(Errors, ErrorField, SingleErrorText, ErrorsGroup, LineNumber = 0, SeveralErrorText = "", RowIndex = Undefined) Export
	
	If Errors = Undefined Then
		Errors = New Structure;
		Errors.Insert("ErrorList", New Array);
		Errors.Insert("ErrorGroups", New Map);
	EndIf;
	
	If Not ValueIsFilled(ErrorsGroup) Then
		// Text for one error is used if the errors group is not filled in.
	Else
		If Errors.ErrorGroups[ErrorsGroup] = Undefined Then
			// Errors group was used only once, text is used for one error.
			Errors.ErrorGroups.Insert(ErrorsGroup, False);
		Else
			// Errors group was used several times, text for several errors is used.
			Errors.ErrorGroups.Insert(ErrorsGroup, True);
		EndIf;
	EndIf;
	
	Error = New Structure;
	Error.Insert("ErrorField",               ErrorField);
	Error.Insert("SingleErrorText",      SingleErrorText);
	Error.Insert("ErrorsGroup",             ErrorsGroup);
	Error.Insert("LineNumber",              LineNumber);
	Error.Insert("SeveralErrorText", SeveralErrorText);
	Error.Insert("RowIndex",             RowIndex);
	
	Errors.ErrorList.Add(Error);
	
EndProcedure

// Reports about errors added using the AddErrorToUser() procedure.
//
// Parameters:
//  Errors  - Undefined - return,
//            value set while using the AddErrorToUser() procedure.
//  Cancel   - Boolean, True is set if errors occur.
//
Procedure ShowErrorsToUser(Errors, Cancel = False) Export
	
	If Errors = Undefined Then
		Return;
	Else
		Cancel = True;
	EndIf;
	
	For Each Error IN Errors.ErrorList Do
		
		If Error.RowIndex = Undefined Then
			RowIndex = Error.LineNumber;
		Else
			RowIndex = Error.RowIndex;
		EndIf;
		
		If Errors.ErrorGroups[Error.ErrorsGroup] <> True Then
			
			MessageToUser(
				Error.SingleErrorText,
				,
				StrReplace(Error.ErrorField, "%1", Format(RowIndex, "NZ=0; NG=")));
		Else
			MessageToUser(
				StrReplace(Error.SeveralErrorText, "%1", Format(Error.LineNumber + 1, "NZ=0; NG=")),
				,
				StrReplace(Error.ErrorField, "%1", Format(RowIndex, "NZ=0; NG=")));
		EndIf;
	EndDo;
	
EndProcedure

// Generates errors text of filling fields and lists.
//
// Parameters:
//  FieldKind       - String - It can take values:
//                  Field, Column, List;
//  MessageKind  - String - It can take values:
//                  Filling, Correctness;
//  FieldName        - String - field name;
//  LineNumber    - String, Number - String number;
//  ListName      - String - list name;
//  MessageText - String - detailed decryption of filling error.
//
// Returns:
//   String - filling text error.
//
Function TextFillingErrors(FieldKind = "Field", MessageKind = "Filling",
	FieldName = "", LineNumber = "", ListName = "", MessageText = "") Export

	If Upper(FieldKind) = "Field" Then
		If Upper(MessageKind) = "FillType" Then
			Pattern = NStr("en='Field ""%1"" is not filled';ru='Поле ""%1"" не заполнено'");
		ElsIf Upper(MessageKind) = "CORRECTNESS" Then
			Pattern = NStr("en='%1 field is filled in incorrectly.
		|
		|%4';ru='Поле ""%1"" заполнено некорректно.
		|
		|%4'");
		EndIf;
	ElsIf Upper(FieldKind) = "Column" Then
		If Upper(MessageKind) = "FillType" Then
			Pattern = NStr("en='%1 column is not filled in in %2 row of %3 list';ru='Не заполнена колонка ""%1"" в строке %2 списка ""%3""'");
		ElsIf Upper(MessageKind) = "CORRECTNESS" Then
			Pattern = NStr("en='Column %1 is filled in incorrectly in %2 row of %3 list.
		|
		|%4';ru='Некорректно заполнена колонка ""%1"" в строке %2 списка ""%3"".
		|
		|%4'");
		EndIf;
	ElsIf Upper(FieldKind) = "LIST" Then
		If Upper(MessageKind) = "FillType" Then
			Pattern = NStr("en='No row has been entered to list %3';ru='Не введено ни одной строки в список ""%3""'");
		ElsIf Upper(MessageKind) = "CORRECTNESS" Then
			Pattern = NStr("en='List %3 is filled in incorrectly.
		|
		|%4';ru='Некорректно заполнен список ""%3"".
		|
		|%4'");
		EndIf;
	EndIf;

	Return StringFunctionsClientServer.SubstituteParametersInString(Pattern, FieldName, LineNumber, ListName, MessageText);

EndFunction

// Generates a path to the specified LineNumber row in the AttributeName column of the TabularSectionName tabular section for showing messages in the form.
// For the shared use with
// the TellUser procedure (for passing to Field or PathToData parameters). 
//
// Parameters:
//  TabularSectionName - String - tabular section name.
//  LineNumber       - Number - tabular section string number.
//  AttributeName      - String - attribute name.
//
// Returns:
//  String - path to table cell.
//
Function PathToTabularSection(Val TabularSectionName, Val LineNumber, 
	Val AttributeName) Export

	Return TabularSectionName + "[" + Format(LineNumber - 1, "NZ=0; NG=0") + "]." + AttributeName;

EndFunction

// Adds values-receiver table with the data from the values-source table.
//
// Parameters:
//  SourceTable - ValueTable - table from which rows for filling will be taken;
//  TargetTable - ValueTable - table to which rows from the source table will be added.
//  
Procedure SupplementTable(SourceTable, TargetTable) Export
	
	For Each SourceTableRow IN SourceTable Do
		
		FillPropertyValues(TargetTable.Add(), SourceTableRow);
		
	EndDo;
	
EndProcedure

// Expands the values table Values table from the Array array.
//
// Parameters:
//  Table - ValueTable - table that should be filled in with values from array;
//  Array  - Array - values array for table filling;
//  FieldName - String - table field name to which it is required to import values from array.
// 
Procedure SupplementTableFromArray(Table, Array, FieldName) Export

	For Each Value IN Array Do
		
		Table.Add()[FieldName] = Value;
		
	EndDo;
	
EndProcedure

// Expands the ReceiverArray array with values from the SourceArray array.
//
// Parameters:
//  ArrayReceiver - Array - array to which it is required to add values.
//  ArraySource - Array - array of values
// for filling, UniqueValuesOnly - Boolean, optional if True, then only those values will be included to the array that do not exist there yet.
// 
Procedure SupplementArray(ArrayReceiver, ArraySource, UniqueValuesOnly = False) Export
	
	For Each Value IN ArraySource Do
		If Not UniqueValuesOnly Or ArrayReceiver.Find(Value) = Undefined Then
			ArrayReceiver.Add(Value);
		EndIf;
	EndDo;
	
EndProcedure

// Expands the StructureReceiver collection with values from the StructureSource collection.
//
// Parameters:
//   StructureReceiver - Structure - Collection to which new values will be added.
//   SourceStructure - Structure - Collection from which pairs Key and Value for filling will be read.
//   WithReplacement - Boolean, Undefined - What to do in intersection places of the source keys and receiver.
//       - True - Replace receiver values (the quickest method).
//       - False   - Do not replace receiver values (skip).
//       - Undefined - Value by default. Throw exception.
//
Procedure ExpandStructure(StructureReceiver, SourceStructure, WithReplacement = Undefined) Export
	
	SearchKey = (WithReplacement = False Or WithReplacement = Undefined);
	For Each KeyAndValue IN SourceStructure Do
		If SearchKey AND StructureReceiver.Property(KeyAndValue.Key) Then
			If WithReplacement = False Then
				Continue;
			Else
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='Source and receiver structures intersection by key %1.';ru='Пересечение структур источника и приемника по ключу ""%1"".'"),
					KeyAndValue.Key);
			EndIf
		EndIf;
		StructureReceiver.Insert(KeyAndValue.Key, KeyAndValue.Value);
	EndDo;
	
EndProcedure

// Clear one item of the conditional design if it is a values list.
// 
// Parameters:
//  ConditionalAppearance - ConditionalAppearance - conditional design of the form item;
//  UserSettingID - String - setting identifier;
//  Value - Arbitrary -  value that should be removed from the design list.
//
Procedure RemoveConditionalAppearanceOfValueList(
						ConditionalAppearance,
						Val UserSettingID,
						Val Value) Export
	
	For Each CAItem IN ConditionalAppearance.Items Do
		If CAItem.UserSettingID = UserSettingID Then
			If CAItem.Filter.Items.Count() = 0 Then
				Return;
			EndIf;
			ItemFilterList = CAItem.Filter.Items[0];
			If ItemFilterList.RightValue = Undefined Then
				Return;
			EndIf;
			ItemOfList = ItemFilterList.RightValue.FindByValue(Value);
			If ItemOfList <> Undefined Then
				ItemFilterList.RightValue.Delete(ItemOfList);
			EndIf;
			ItemFilterList.RightValue = ItemFilterList.RightValue;
			Return;
		EndIf;
	EndDo;
	
EndProcedure

// Deletes all listings of the value passed from array.
//
// Parameters:
//  Array - Array - array from which it is required to delete value;
//  Value - Arbitrary - value removed from the array.
// 
Procedure DeleteAllOccurencesOfValueFromArray(Array, Value) Export
	
	CollectionItemsQuantity = Array.Count();
	
	For ReverseIndex = 1 To CollectionItemsQuantity Do
		
		IndexOf = CollectionItemsQuantity - ReverseIndex;
		
		If Array[IndexOf] = Value Then
			
			Array.Delete(IndexOf);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Deletes all values listings of the specified type.
//
// Parameters:
//  Array - Array - Array from which it is required to delete values.;
//  Type - Type - values type that should be deleted from the array.
// 
Procedure DeleteAllTypeOccurrencesFromArray(Array, Type) Export
	
	CollectionItemsQuantity = Array.Count();
	
	For ReverseIndex = 1 To CollectionItemsQuantity Do
		
		IndexOf = CollectionItemsQuantity - ReverseIndex;
		
		If TypeOf(Array[IndexOf]) = Type Then
			
			Array.Delete(IndexOf);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Deletes one value from array.
//
// Parameters:
//  Array - Array - array from which it is required to delete value;
//  Value - Array - value removed from the array.
// 
Procedure DeleteValueFromArray(Array, Value) Export
	
	IndexOf = Array.Find(Value);
	
	If IndexOf <> Undefined Then
		
		Array.Delete(IndexOf);
		
	EndIf;
	
EndProcedure

// Deletes duplicate array items.
//
// Parameters:
//  Array - Array - custom values array.
//
// Returns:
//  Array;
Function CollapseArray(Array) Export
	Result = New Array;
	SupplementArray(Result, Array, True);
	Return Result;
EndFunction

// Fills in collection-receiver with values from collection-source.
// As collections of source and receiver types may act:
// ValuesTable; ValuesTree; ValuesList etc.
//
// Parameters:
//  SourceCollection - AnyCollection - values collection that is a source for data filling.;
//  TargetCollection - AnyCollection - values collection that is a receiver for the data filling.
// 
Procedure FillPropertyCollection(SourceCollection, TargetCollection) Export
	
	For Each Item IN SourceCollection Do
		
		FillPropertyValues(TargetCollection.Add(), Item);
		
	EndDo;
	
EndProcedure

// Receives values from selected items of values list.
// 
// Parameters:
//  List - ValueList - values list from which the values array will be generated;
// 
// Returns:
//  Array - items array from the marked items of the values list.
//
Function GetArrayOfMarkedListItems(List) Export
	
	// Return value of the function.
	Array = New Array;
	
	For Each Item IN List Do
		
		If Item.Check Then
			
			Array.Add(Item.Value);
			
		EndIf;
		
	EndDo;
	
	Return Array;
EndFunction

// Subtracts one items array from another array. Returns subtracting result.
// 
// Parameters:
//  Array - Array - items array from which it is required to execute subtraction;
//  SubstractionArray - Array - items array that will be subtracted.
// 
// Returns:
//  Array - result of two arrays subtraction.
//
Function ReduceArray(Array, SubstractionArray) Export
	
	Result = New Array;
	
	For Each Item IN Array Do
		
		If SubstractionArray.Find(Item) = Undefined Then
			
			Result.Add(Item);
			
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

// Converts ScheduledJobSchedule to the structure.
// 
// Parameters:
//  Schedule - ScheduledJobSchedule -.
// 
// Returns:
//  Structure.
//
Function ScheduleIntoStructure(Val Schedule) Export
	
	ScheduleValue = Schedule;
	If ScheduleValue = Undefined Then
		ScheduleValue = New JobSchedule();
	EndIf;
	FieldList = "CompletionTime,EndTime,BeginTime,EndDate,BeginDate,DayInMonth,WeekDayInMonth," + 
		"WeekDays,CompletionInterval,Months,RepeatPause,WeeksPeriod,RepeatPeriodInDay,DaysRepeatPeriod";
	Result = New Structure(FieldList);
	FillPropertyValues(Result, ScheduleValue, FieldList);
	DetailedDailySchedules = New Array;
	For Each ScheduleDaily IN Schedule.DetailedDailySchedules Do
		DetailedDailySchedules.Add(ScheduleIntoStructure(ScheduleDaily));
	EndDo;
	Result.Insert("DetailedDailySchedules", DetailedDailySchedules);
	Return Result;
	
EndFunction		

// Converts the structure to ScheduledJobSchedule.
// 
// Parameters:
//  ScheduleStructure - Structure -.
// 
// Returns:
//  ScheduledJobSchedule.
//
Function StructureIntoSchedule(Val ScheduleStructure) Export
	
	If ScheduleStructure = Undefined Then
		Return New JobSchedule();
	EndIf;
	FieldList = "CompletionTime,EndTime,BeginTime,EndDate,BeginDate,DayInMonth,WeekDayInMonth," + 
		"WeekDays,CompletionInterval,Months,RepeatPause,WeeksPeriod,RepeatPeriodInDay,DaysRepeatPeriod";
	Result = New JobSchedule;
	FillPropertyValues(Result, ScheduleStructure, FieldList);
	DetailedDailySchedules = New Array;
	For Each Schedule IN ScheduleStructure.DetailedDailySchedules Do
		  DetailedDailySchedules.Add(StructureIntoSchedule(Schedule));
	EndDo;
	Result.DetailedDailySchedules = DetailedDailySchedules;  
	Return Result;
	
EndFunction		

// Creates an instance copy of the specified object.
//
// Parameters:
//  Source - Arbitrary - object that is required to be copied.
//
// Returns:
//  Arbitrary - copy of the object passed in the Source parameter.
//
// Note:
//  Function can not be used for object types (CatalogObject, DocumentObject etc.).
Function CopyRecursive(Source) Export
	
	Var Receiver;
	
	SourceType = TypeOf(Source);
	If SourceType = Type("Structure") Then
		Receiver = CopyStructure(Source);
	ElsIf SourceType = Type("Map") Then
		Receiver = CopyMap(Source);
	ElsIf SourceType = Type("Array") Then
		Receiver = CopyArray(Source);
	ElsIf SourceType = Type("ValueList") Then
		Receiver = CopyValueList(Source);
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	ElsIf SourceType = Type("ValueTable") Then
		Receiver = Source.Copy();
#EndIf
	Else
		Receiver = Source;
	EndIf;
	
	Return Receiver;
	
EndFunction

// Creates copy of the Structure type value.
// 
// Parameters:
//  SourceStructure - Structure - copied structure.
// 
// Returns:
//  Structure - copy the source structure.
//
Function CopyStructure(SourceStructure) Export
	
	ResultStructure = New Structure;
	
	For Each KeyAndValue IN SourceStructure Do
		ResultStructure.Insert(KeyAndValue.Key, CopyRecursive(KeyAndValue.Value));
	EndDo;
	
	Return ResultStructure;
	
EndFunction

// Creates value copy of the Match type.
// 
// Parameters:
//  SourceMap - Map - match copy of which you should receive.
// 
// Returns:
//  Map - copy of the source match.
//
Function CopyMap(SourceMap) Export
	
	ResultMap = New Map;
	
	For Each KeyAndValue IN SourceMap Do
		ResultMap.Insert(KeyAndValue.Key, CopyRecursive(KeyAndValue.Value));
	EndDo;
	
	Return ResultMap;

EndFunction

// Creates the value copy of the Array type.
// 
// Parameters:
//  ArraySource - Array - array copy of which should be received.
// 
// Returns:
//  Array - copy of the source array.
//
Function CopyArray(ArraySource) Export
	
	ResultArray = New Array;
	
	For Each Item IN ArraySource Do
		ResultArray.Add(CopyRecursive(Item));
	EndDo;
	
	Return ResultArray;
	
EndFunction

// Create the value copy of the ValuesList type.
// 
// Parameters:
//  SourceList - ValueList - Values list copy of which is required to be received.
// 
// Returns:
//  ValueList - copy of the source values list.
//
Function CopyValueList(SourceList) Export
	
	ResultList = New ValueList;
	
	For Each ItemOfList IN SourceList Do
		ResultList.Add(
			CopyRecursive(ItemOfList.Value), 
			ItemOfList.Presentation, 
			ItemOfList.Check, 
			ItemOfList.Picture);
	EndDo;
	
	Return ResultList;
	
EndFunction

// Compares values list items or arrays by values.
Function ValueListsIdentical(List1, List2) Export
	
	EqualLists = True;
	
	For Each ListItem1 IN List1 Do
		If FindInList(List2, ListItem1) = Undefined Then
			EqualLists = False;
			Break;
		EndIf;
	EndDo;
	
	If EqualLists Then
		For Each ListItem2 IN List2 Do
			If FindInList(List1, ListItem2) = Undefined Then
				EqualLists = False;
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	Return EqualLists;
	
EndFunction

// Creates array and puts passed value to it.
Function ValueInArray(Value) Export
	
	Array = New Array;
	Array.Add(Value);
	
	Return Array;
	
EndFunction

// Procedure manages the tabular document field state.
//
// Parameters:
//  SpreadsheetDocumentField - FormField - form field with
//                            the TabularDocumentField kind for which it is required to set the state.
//  Status               - String - set the state kind.
//
Procedure SetSpreadsheetDocumentFieldState(SpreadsheetDocumentField, Status = "DontUse") Export
	
	If TypeOf(SpreadsheetDocumentField) = Type("FormField") 
		AND SpreadsheetDocumentField.Type = FormFieldType.SpreadsheetDocumentField Then
		StatePresentation = SpreadsheetDocumentField.StatePresentation;
		If Upper(Status) = "DONTUSE" Then
			StatePresentation.Visible                      = False;
			StatePresentation.AdditionalShowMode = AdditionalShowMode.DontUse;
			StatePresentation.Picture                       = New Picture;
			StatePresentation.Text                          = "";
		ElsIf Upper(Status) = "IRRELEVANCE" Then
			StatePresentation.Visible                      = True;
			StatePresentation.AdditionalShowMode = AdditionalShowMode.Irrelevance;
			StatePresentation.Picture                       = New Picture;
			StatePresentation.Text                          = NStr("en='Report is not generated. Click Create to generate the report.';ru='Отчет не сформирован. Нажмите ""Сформировать"" для получения отчета.'");;
		ElsIf Upper(Status) = "REPORTCREATION" Then  
			StatePresentation.Visible                      = True;
			StatePresentation.AdditionalShowMode = AdditionalShowMode.Irrelevance;
			StatePresentation.Picture                       = PictureLib.LongOperation48;
			StatePresentation.Text                          = NStr("en='Generating the report...';ru='Отчет формируется...'");
		Else
			Raise(NStr("en=""Invalid parameter value (parameter number '2')"";ru=""Недопустимое значение параметра (параметр номер '2')"""));
		EndIf;
	Else
		Raise(NStr("en=""Invalid parameter value (parameter number '1')"";ru=""Недопустимое значение параметра (параметр номер '1')"""));
	EndIf;
	
EndProcedure

// Receives configuration version number without the batch number.
// 
// Parameters:
//  Version - String - configuration version in
//                    RR.PP.ZZ.SS format where SS - batch number that will be deleted.
// 
//  Returns:
//  String - configuration version number without build number in RR.PP.ZZ format
//
Function ConfigurationVersionWithoutAssemblyNumber(Val Version) Export
	
	Array = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Version, ".");
	
	If Array.Count() < 3 Then
		Return Version;
	EndIf;
	
	Result = "[Edition].[Subedition].[Release]";
	Result = StrReplace(Result, "[Edition]",    Array[0]);
	Result = StrReplace(Result, "[Subedition]", Array[1]);
	Result = StrReplace(Result, "[Release]",       Array[2]);
	
	Return Result;
EndFunction

// Compare two version rows.
//
// Parameters:
//  VersionString1  - String - version number in RR.{P|PP}.ZZ.SS. format
//  VersionString2  - String - second compared version number.
//
// Returns:
//   Number   - more than 0 if VersionRow1 > VersionRow2; 0 if the versions are equal.
//
Function CompareVersions(Val VersionString1, Val VersionString2) Export
	
	Row1 = ?(IsBlankString(VersionString1), "0.0.0.0", VersionString1);
	Row2 = ?(IsBlankString(VersionString2), "0.0.0.0", VersionString2);
	Version1 = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Row1, ".");
	If Version1.Count() <> 4 Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Wrong format of the VersionRow1 parameter: %1';
				 |ru='Неправильный формат параметра СтрокаВерсии1: %1'"), VersionString1);
	EndIf;
	Version2 = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Row2, ".");
	If Version2.Count() <> 4 Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
	    	NStr("en='Wrong format of the VersionRow2 parameter: %1';
				 |ru='Неправильный формат параметра СтрокаВерсии2: %1'"), VersionString2);
	EndIf;
	
	Result = 0;
	For Digit = 0 To 3 Do
		Result = Number(Version1[Digit]) - Number(Version2[Digit]);
		If Result <> 0 Then
			Return Result;
		EndIf;
	EndDo;
	Return Result;
	
EndFunction

// Compare two version rows.
//
// Parameters:
//  VersionString1  - String - version number in RR.{P|PP}.ZZ.format
//  VersionString2  - String - second compared version number.
//
// Returns:
//   Number   - more than 0 if VersionRow1 > VersionRow2; 0 if the versions are equal.
//
Function CompareVersionsWithoutBatchNumber(Val VersionString1, Val VersionString2) Export
	
	Row1 = ?(IsBlankString(VersionString1), "0.0.0", VersionString1);
	Row2 = ?(IsBlankString(VersionString2), "0.0.0", VersionString2);
	Version1 = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Row1, ".");
	If Version1.Count() <> 3 Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Wrong format of the VersionRow1 parameter: %1';ru='Неправильный формат параметра СтрокаВерсии1: %1'"), VersionString1);
	EndIf;
	Version2 = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Row2, ".");
	If Version2.Count() <> 3 Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
	    	NStr("en='Wrong format of the VersionRow2 parameter: %1';ru='Неправильный формат параметра СтрокаВерсии2: %1'"), VersionString2);
	EndIf;
	
	Result = 0;
	For Digit = 0 To 2 Do
		Result = Number(Version1[Digit]) - Number(Version2[Digit]);
		If Result <> 0 Then
			Return Result;
		EndIf;
	EndDo;
	Return Result;
	
EndFunction

// Receives a row containing structure keys separated by the separator character.
//
// Parameters:
// Structure - Structure - Structure keys of which are converted to row.
// Delimiter - String - Separator that is input to row between structure keys.
//
// Returns:
// String - String containing structure keys separated by a separator.
//
Function StructureKeysToString(Structure, Delimiter = ",") Export
	
	Result = "";
	
	For Each Item IN Structure Do
		
		SeparatorChar = ?(IsBlankString(Result), "", Delimiter);
		
		Result = Result + SeparatorChar + Item.Key;
		
	EndDo;
	
	Return Result;
	
EndFunction

// Returns value of the structure property.
//
// Parameters:
//   Structure - Structure, FixedStructure - Object from which it is required to read the key value.
//   Key - String - Structure property name for which it is required to read value.
//   DefaultValue - Arbitrary - Optional. Returned when there is no value
//                                        by the specified key in the structure.
//       To make it quicker, it is recommended to pass only
//       quickly calculated values (for example, primitive types) but execute the initialization of more
//       difficult values after check of the received value (only if needed).
//
// Returns:
//   Arbitrary - Value of the structure property. DefaultValue if the structure does not contain the specified property.
//
Function StructureProperty(Structure, Key, DefaultValue = Undefined) Export
	
	If Structure = Undefined Then
		Return Undefined;
	EndIf;
	
	Result = DefaultValue;
	If Structure.Property(Key, Result) Then
		Return Result;
	Else
		Return DefaultValue;
	EndIf;
	
EndFunction

// Returns COM-class name for work with 1C:Enterprise 8 via COM-connection.
//
Function COMConnectorName() Export
	
	SystemInfo = New SystemInfo;
	VersionSubstrings = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(
		SystemInfo.AppVersion, ".");
	Return "v" + VersionSubstrings[0] + VersionSubstrings[1] + ".COMConnector";
	
EndFunction

// Establishes external connection with the infobase by the passed connection
// parameters and returns a pointer to this connection.
// 
// Parameters:
//  Parameters - Structure - parameters for setting the external connection with the infobase.
//                          For the
//                          properties, see the CommonUseClientServer.ParametrsForSettingExternalConnectionStructure):
//
//    * InfobaseWorkVariant             - Number - Infobase work variant: 0 - file; 1 -
//                                                            client-server;
//    * InfobaseFolder                   - String - The directory where infobase that works in file mode is placed;
//    * Server1CEnterpriseName                     - String - Server1C:Enterprise Name;
//    * InfobaseNameOn1CEnterpriseServer - String - Infobase name on 1C:Enterprise server;
//    * OperatingSystemAuthentication           - Boolean - Defines that operating system authentication
//                                                             is used for external connection to the infobase;
//    * UserName                             - String - Infobase user name;
//    * UserPassword                          - String - Infobase user password.
// 
//  ErrorMessageString - String - if an error occurs while establishing external
//                                     connection, then the error detailed description is put to this parameter.
//
// Returns:
//  COMObject, Undefined -
//    in case of successful external connection, pointer to COM-object of connection is returned;
//    in case of an error, Undefined is returned.
//
Function EstablishExternalConnection(Parameters, ErrorMessageString = "", ErrorAttachingAddIn = False) Export
	Result = InstallOuterDatabaseJoin(Parameters);
	ErrorAttachingAddIn = Result.ErrorAttachingAddIn;
	ErrorMessageString     = Result.DetailedErrorDescription;
	
	Return Result.Join;
EndFunction

// Establishes external connection with the infobase by the passed connection
// parameters and returns a pointer to this connection.
// 
// Parameters:
//  Parameters - Structure - parameters for setting the external connection with the infobase.
//                          For the
//                          properties, see the CommonUseClientServer.ParametrsForSettingExternalConnectionStructure):
// 
//   * InfobaseWorkVariant             - Number  -  Infobase work variant: 0 - file; 1 -
//                                                            client-server;
//   * InfobaseFolder                   - String - The directory where infobase that works in file mode is placed;
//   * Server1CEnterpriseName                     - String - Server1C:Enterprise Name;
//   * InfobaseNameOn1CEnterpriseServer - String - Infobase name on 1C:Enterprise server;
//   * OperatingSystemAuthentication           - Boolean - Defines that operating system authentication
//                                                            is used for external connection to the infobase;
//   * UserName                             - String - Infobase user name;
//   * UserPassword                          - String - Infobase user password.
// 
// Returns:
//  Structure -
//    * JOIN                  - COMObject, Undefined - pointer to connection COM-object or
//                                    Undefined in case of an error;
//    * BriefErrorDescription       - String - short description of error;
//    * DetailErrorDescription     - String - detail error description;
//    * ErrorAttachingComponent - Boolean - check box of COM connection error
//
Function InstallOuterDatabaseJoin(Parameters) Export
	
	Result = New Structure("Connection, ErrorShortInfo, DetailedErrorDescription, ErrorAttachingAddIn",
		Undefined, "", "", False);
	
	#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
		IsLinux = CommonUse.ThisLinuxServer();
		ErrorShortInfo = NStr("en='Direct connection to the infobase is unavailable on the server under OS Linux.';ru='Прямое подключение к информационной базе недоступно на сервере под управлением ОС Linux.'");
	#Else
		IsLinux = IsLinuxClient();
		ErrorShortInfo = NStr("en='Direct connection to the infobase is unavailable on client managed by Linux OS.';ru='Прямое подключение к информационной базе недоступно на клиенте под управлением ОС Linux.'");
	#EndIf
	
	If IsLinux Then
		Result.Connection = Undefined;
		Result.ErrorShortInfo = ErrorShortInfo;
		Result.DetailedErrorDescription = ErrorShortInfo;
		Return Result;
	EndIf;
	
	Try
		COMConnector = New COMObject(COMConnectorName()); // "V83.COMConnector"
	Except
		Information = ErrorInfo();
		ErrorMessageString = NStr("en='Unable to connect to another application: %1';ru='Не удалось подключиться к другой программе: %1'");
		
		Result.ErrorAttachingAddIn = True;
		Result.DetailedErrorDescription     = StringFunctionsClientServer.SubstituteParametersInString(ErrorMessageString, DetailErrorDescription(Information));
		Result.ErrorShortInfo       = StringFunctionsClientServer.SubstituteParametersInString(ErrorMessageString, BriefErrorDescription(Information));
		
		Return Result;
	EndTry;
	
	FileModeWork = Parameters.InfobaseOperationMode = 0;
	
	// Check if the parameters are specified correctly.
	FillCheckingError = False;
	If FileModeWork Then
		
		If IsBlankString(Parameters.InfobaseDirectory) Then
			ErrorMessageString = NStr("en='Infobase directory location has not been set.';ru='Не задано месторасположение каталога информационной базы.'");
			FillCheckingError = True;
		EndIf;
		
	Else
		
		If IsBlankString(Parameters.PlatformServerName) Or IsBlankString(Parameters.InfobaseNameAtPlatformServer) Then
			ErrorMessageString = NStr("en='Mandatory connection parameters are not specified: Server name""; Infobase name on server.';ru='Не заданы обязательные параметры подключения: ""Имя сервера""; ""Имя информационной базы на сервере"".'");
			FillCheckingError = True;
		EndIf;
		
	EndIf;
	
	If FillCheckingError Then
		
		Result.DetailedErrorDescription = ErrorMessageString;
		Result.ErrorShortInfo   = ErrorMessageString;
		Return Result;
		
	EndIf;
	
	// Generate connection row.
	ConnectionStringTemplate = "[BaseRow][AuthenticationString]";
	
	If FileModeWork Then
		BaseRow = "File = ""&InfobaseDirectory""";
		BaseRow = StrReplace(BaseRow, "&InfobaseDirectory", Parameters.InfobaseDirectory);
	Else
		BaseRow = "Srvr = ""&1CEnterpriseServerName""; Ref = ""&InfobaseNameOn1CEnterpriseServer""";
		BaseRow = StrReplace(BaseRow, "&1CEnterpriseServerName",                     Parameters.PlatformServerName);
		BaseRow = StrReplace(BaseRow, "&InfobaseNameOn1CEnterpriseServer", Parameters.InfobaseNameAtPlatformServer);
	EndIf;
	
	If Parameters.OSAuthentication Then
		AuthenticationString = "";
	Else
		
		If Find(Parameters.UserName, """") Then
			Parameters.UserName = StrReplace(Parameters.UserName, """", """""");
		EndIf;
		
		If Find(Parameters.UserPassword, """") Then
			Parameters.UserPassword = StrReplace(Parameters.UserPassword, """", """""");
		EndIf;
		
		AuthenticationString = "; Usr = ""&UserName""; Pwd = ""&UserPassword""";
		AuthenticationString = StrReplace(AuthenticationString, "&UserName",    Parameters.UserName);
		AuthenticationString = StrReplace(AuthenticationString, "&UserPassword", Parameters.UserPassword);
	EndIf;
	
	ConnectionString = StrReplace(ConnectionStringTemplate, "[BaseRow]", BaseRow);
	ConnectionString = StrReplace(ConnectionString, "[AuthenticationString]", AuthenticationString);
	
	Try
		Result.Connection = COMConnector.Connect(ConnectionString);
	Except
		Information = ErrorInfo();
		ErrorMessageString = NStr("en='Unable to connect to another application: %1';ru='Не удалось подключиться к другой программе: %1'");
		
		Result.ErrorAttachingAddIn = True;
		Result.DetailedErrorDescription     = StringFunctionsClientServer.SubstituteParametersInString(ErrorMessageString, DetailErrorDescription(Information));
		Result.ErrorShortInfo       = StringFunctionsClientServer.SubstituteParametersInString(ErrorMessageString, BriefErrorDescription(Information));
		
	EndTry;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for events processor and call of optional subsystems.

// Outdated. You should use CommonUse.SubsystemExists or CommonUseClient.SubsystemExist.
// Returns True if the subsystem exists.
//
// Parameters:
//  SubsystemFullName - String. Full metadata object name, subsystem without words "Subsystem.".
//                        For example, StandardSubsystems.BasicFunctionality".
//
// Example of optional subsystem call:
//
//  If CommonUse.SubsystemExists("StandardSubsystems.AccessManagement")
//  	Then AccessControlModule = CommonUse.CommonModule("AccessManagement");
//  	AccessManagementModule.<Method name>();
//  EndIf;
//
// Returns:
//  Boolean.
//
Function SubsystemExists(SubsystemFullName) Export
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	Return CommonUse.SubsystemExists(SubsystemFullName);
#Else
	Return CommonUseClient.SubsystemExists(SubsystemFullName);
#EndIf

EndFunction

// Outdated. You should use CommonUse.CommonModule or CommonUseClient.CommonModule.
// It returns a reference to the common module by name.
//
// Parameters:
//  Name          - String - common module name, for example:
//                 "CommonUse",
//                 "CommonUseClient".
//
// Returns:
//  CommonModule.
//
Function CommonModule(Name) Export
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	Module = CommonUse.CommonModule(Name);
#Else
	Module = CommonUseClient.CommonModule(Name);
#EndIf
	
	Return Module;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Functions for work with files.
//

// Adds the end character-separator to the passed directory path if it is not available.
//
// Parameters:
//  DirectoryPath - String - path to folder.
//
// Returns:
//  String - path to directory with the end character-separator.
//
// Usage examples:
//  Result = AddFinalPathSeparator("C:\My directory");  returns "C://\My directory\".
//  Result = AddFinalPathSeparator("C:\My directory\");  returns "C:\My directory\".
//  Result = AddFinalPathSeparator("%APPDATA%");  returns "%APPDATA%\"
//
Function AddFinalPathSeparator(Val DirectoryPath, Val Delete_Platform = Undefined) Export
	If IsBlankString(DirectoryPath) Then
		Return DirectoryPath;
	EndIf;
	
	CharToAdd = GetPathSeparator();
	
	If Right(DirectoryPath, 1) = CharToAdd Then
		Return DirectoryPath;
	Else 
		Return DirectoryPath + CharToAdd;
	EndIf;
EndFunction

// Creates the file full name from directory and attachment file name.
//
// Parameters:
//  DirectoryName  - String - path to file directory on the disk.
//  FileName     - String - attachment file name without directory name.
//
// Returns:
//   String - file full name considering the directory.
//
Function GetFullFileName(Val DirectoryName, Val FileName) Export

	If Not IsBlankString(FileName) Then
		
		Slash = "";
		If (Right(DirectoryName, 1) <> "\") AND (Right(DirectoryName, 1) <> "/") Then
			Slash = ?(Find(DirectoryName, "\") = 0, "/", "\");
		EndIf;
		
		Return DirectoryName + Slash + FileName;
		
	Else
		
		Return DirectoryName;
		
	EndIf;

EndFunction

// Disassembles file full name.
//
// Parameters:
//  FullFileName - String - full path to the file.
//  IsFolder - Boolean - shows that it is required to disassemble the folder full name, not the attachment file name.
//
// Returns:
//   Structure - attachment file name reduced to its parts(similar to File object properties):
// 	DescriptionFull - Contains the full path to the file i.e. completely corresponds to the FullFileName input parameter.
// 	Path - Contains path to directory where file is located.
// 	Name - Contains attachment file name with extension, without path to file.
// 	Extension - Contains the file extension.
// 	BaseName - Contains the attachment file name without the extension and without the path to file.
// 		Example: if FullFileName = c:\temp\test.txt, the structure is filled in in the following way:
// 			FullName: "c:\temp\test.txt".
// 			Path:
// 			c:\temp\ Name:
// 			test.txt Extension:
// 			NameWithoutExtension: .txt : test.
//
Function SplitFullFileName(Val FullFileName, IsFolder = False) Export
	
	FileNameStructure = New Structure("DescriptionFull,Path,Name,Extension,BaseName");
	
	// Remove final slash from the full attachment file name and save the full name to the structure.
	If IsFolder AND (Right(FullFileName, 1) = "/" Or Right(FullFileName, 1) = "\") Then
		If IsFolder Then
			FullFileName = Mid(FullFileName, 1, StrLen(FullFileName) - 1);
		Else
			// If path to file ends with a slash, then file has no name.
			FileNameStructure.Insert("DescriptionFull", FullFileName); 
			FileNameStructure.Insert("Path", FullFileName); 
			FileNameStructure.Insert("Name", ""); 
			FileNameStructure.Insert("Extension", ""); 
			FileNameStructure.Insert("BaseName", ""); 
			Return FileNameStructure;
		EndIf;
	EndIf;
	FileNameStructure.Insert("DescriptionFull", FullFileName); 
	
	// If the full attachment file name is empty, return the remaining structure parameters empty.
	If StrLen(FullFileName) = 0 Then 
		FileNameStructure.Insert("Path", ""); 
		FileNameStructure.Insert("Name", ""); 
		FileNameStructure.Insert("Extension", ""); 
		FileNameStructure.Insert("BaseName", ""); 
		Return FileNameStructure;
	EndIf;
	
	// Select a file path and attachment file name.
	If Find(FullFileName, "/") > 0 Then
		SeparatorPosition = StringFunctionsClientServer.FindCharFromEnd(FullFileName, "/");
	ElsIf Find(FullFileName, "\") > 0 Then
		SeparatorPosition = StringFunctionsClientServer.FindCharFromEnd(FullFileName, "\");
	Else
		SeparatorPosition = 0;
	EndIf;
	FileNameStructure.Insert("Path", Left(FullFileName, SeparatorPosition)); 
	FileNameStructure.Insert("Name", Mid(FullFileName, SeparatorPosition + 1));
	
	// Folders do not have extensions, select extension for file.
	If IsFolder Then
		FileNameStructure.Insert("Extension", "");
		FileNameStructure.Insert("BaseName", FileNameStructure.Name);
	Else
        DotPosition = StringFunctionsClientServer.FindCharFromEnd(FileNameStructure.Name, ".");
		If DotPosition = 0 Then
			FileNameStructure.Insert("Extension", "");
			FileNameStructure.Insert("BaseName", FileNameStructure.Name);
		Else
			FileNameStructure.Insert("Extension", Mid(FileNameStructure.Name, DotPosition));
			FileNameStructure.Insert("BaseName", Left(FileNameStructure.Name, DotPosition - 1));
		EndIf;
	EndIf;
	
	Return FileNameStructure;
	
EndFunction

// Dissembles URI string and returns it as a structure.
// On basis of RFC 3986.
//
// Parameters:
//     URLString - String - ref to the resource in the format:
//                          <schema>://<login>:<passwork>@<host>:<port>/<path>?<parameters>#<anchor>.
//
// Returns:
//     Structure - URI constituent parts according to the format:
//         * Schema         - String.
//         * Login         - String.
//         * Password        - String.
//         * ServerName    - String - part <host>:<port> input parameter.
//         * Host          - String.
//         * Port          - String.
//         * PathOnServer - String - part <path >?<parameters>#<anchor> input parameter.
//
Function URLStructure(Val URLString) Export
	
	URLString = TrimAll(URLString);
	
	// schema
	Schema = "";
	Position = Find(URLString, "://");
	If Position > 0 Then
		Schema = Lower(Left(URLString, Position - 1));
		URLString = Mid(URLString, Position + 3);
	EndIf;

	// Connection row and path on server.
	ConnectionString = URLString;
	PathAtServer = "";
	Position = Find(ConnectionString, "/");
	If Position > 0 Then
		PathAtServer = Mid(ConnectionString, Position + 1);
		ConnectionString = Left(ConnectionString, Position - 1);
	EndIf;
		
	// Information about users and server name.
	AuthorizationString = "";
	ServerName = ConnectionString;
	Position = Find(ConnectionString, "@");
	If Position > 0 Then
		AuthorizationString = Left(ConnectionString, Position - 1);
		ServerName = Mid(ConnectionString, Position + 1);
	EndIf;
	
	// login and password
	Login = AuthorizationString;
	Password = "";
	Position = Find(AuthorizationString, ":");
	If Position > 0 Then
		Login = Left(AuthorizationString, Position - 1);
		Password = Mid(AuthorizationString, Position + 1);
	EndIf;
	
	// host and port
	Host = ServerName;
	Port = "";
	Position = Find(ServerName, ":");
	If Position > 0 Then
		Host = Left(ServerName, Position - 1);
		Port = Mid(ServerName, Position + 1);
	EndIf;
	
	Result = New Structure;
	Result.Insert("Schema", Schema);
	Result.Insert("Login", Login);
	Result.Insert("Password", Password);
	Result.Insert("ServerName", ServerName);
	Result.Insert("Host", Host);
	Result.Insert("Port", ?(IsBlankString(Port), Undefined, Number(Port)));
	Result.Insert("PathAtServer", PathAtServer);
	
	Return Result;
	
EndFunction

// Function lays out Row to rows array, using ./\" as separator.
Function SortStringByPointsAndSlashes(Val String) Export
	
	Var CurrentPosition;
	
	Fragments = New Array;
	
	StartPosition = 1;
	
	For CurrentPosition = 1 To StrLen(String) Do
		CurrentChar = Mid(String, CurrentPosition, 1);
		If CurrentChar = "." Or CurrentChar = "/" Or CurrentChar = "\" Then
			CurrentFragment = Mid(String, StartPosition, CurrentPosition - StartPosition);
			StartPosition = CurrentPosition + 1;
			Fragments.Add(CurrentFragment);
		EndIf;
	EndDo;
	
	If StartPosition <> CurrentPosition Then
		CurrentFragment = Mid(String, StartPosition, CurrentPosition - StartPosition);
		Fragments.Add(CurrentFragment);
	EndIf;
	
	Return Fragments;
	
EndFunction

// Selects an extension from the attachment file name (characters set after the last point).
//
// Parameters:
//  FileName - String - attachment file name with or without directory name.
//
// Returns:
//   String - file extension.
//
Function GetFileNameExtension(Val FileName) Export
	
	Extension = "";
	
	CharPosition = StrLen(FileName);
	While CharPosition >= 1 Do
		
		If Mid(FileName, CharPosition, 1) = "." Then
			
			Extension = Mid(FileName, CharPosition + 1);
			Break;
		EndIf;
		
		CharPosition = CharPosition - 1;
	EndDo;

	Return Extension;
	
EndFunction

// Converts a file extension to the low register without point.
//
// Parameters:
//  Extension - String - Extension for conversion.
//
// Returns:
//  Row.
//
Function ExtensionWithoutDot(Val Extension) Export
	
	Extension = Lower(TrimAll(Extension));
	
	If Mid(Extension, 1, 1) = "." Then
		Extension = Mid(Extension, 2);
	EndIf;
	
	Return Extension;
	
EndFunction

// Returns file system path separator.
// 
// Parameters:
//  Platform - Undefined -
//                on client - client file system path separator.
//                At server - separator of server file system path.
// 
//            - PlatformType - file system path separator
//                             for the specified platform type.
//
Function PathSeparator(Platform = Undefined) Export
	
	If Platform = Undefined Then
		
	#If ThickClientOrdinaryApplication Or ExternalConnection Then
		SystemInfo = New SystemInfo;
		Platform = SystemInfo.PlatformType;
	#ElsIf Client Then
		Platform = CommonUseClientReUse.ClientPlatformType();
	#Else
		Platform = CommonUseReUse.ServerPlatformType();
	#EndIf
	
	EndIf;
	
	If Platform = PlatformType.Windows_x86
	 OR Platform = PlatformType.Windows_x86_64 Then
		
		Return "\";
	Else
		Return "/";
	EndIf;
	
EndFunction

// Returns attachment file name with extension.
// If an extension is empty, then the point is not added.
//
// Parameters:
//  BaseName - String - .
//  Extension       - String - .
//
// Returns:
//  Row.
//
Function GetNameWithExtention(BaseName, Extension) Export
	
	NameWithExtension = BaseName;
	
	If Extension <> "" Then
		NameWithExtension = NameWithExtension + "." + Extension;
	EndIf;
	
	Return NameWithExtension;
	
EndFunction

// Returns invalid characters row.
// According to http://en.wikipedia.org/wiki/Filename - in the Reserved characters and words section.
// Returns:
//   String - invalid characters row.
Function GetProhibitedCharsInFileName() Export

	ProhibitedChars = """/\[]:;|=?*<>";
	Return ProhibitedChars;

EndFunction

// Checks if there are invalid characters in the attachment file name.
//
// Parameters:
//  FileName  - String -.
//
// Returns:
//   Array   - array of found invalid characters in the attachment file name.
//              If invalid characters are not found, an empty array is returned.
Function FindProhibitedCharsInFileName(FileName) Export

	ProhibitedChars = GetProhibitedCharsInFileName();
	
	FoundProhibitedCharArray = New Array;
	
	For CharPosition = 1 To StrLen(ProhibitedChars) Do
		CharToCheck = Mid(ProhibitedChars,CharPosition,1);
		If Find(FileName,CharToCheck) <> 0 Then
			FoundProhibitedCharArray.Add(CharToCheck);
		EndIf;
	EndDo;
	
	Return FoundProhibitedCharArray;

EndFunction

// Replaces invalid characters in the attachment file name.
//
// Parameters:
//  FileName     - String - original attachment file name.
//  ReplaceWith  - String - String for which it is required to replace invalid characters.
//
// Returns:
//   String - converted attachment file name.
//
Function ReplaceProhibitedCharsInFileName(Val FileName, ReplaceWith = " ") Export

	Result = FileName;
	FoundProhibitedCharArray = FindProhibitedCharsInFileName(Result);
	For Each DisallowedChar IN FoundProhibitedCharArray Do
		Result = StrReplace(Result, DisallowedChar, ReplaceWith);
	EndDo;
	
	Return Result;

EndFunction

////////////////////////////////////////////////////////////////////////////////
// Functions for work with mailing addresses.
//

// Parses a row with the email addresses according to RFC 5322 standard with restrictions.
//
// restriction:
//  1. It is allowed to use only letters, digits, underscore, hyphen and @ in address.
//  2. <>[]() brackets characters are allowed but ignored by replacements with gaps.
//  3. Groups prohibited.
//
// Parameters:
//  String - String - String containing email addresses (mailbox-list).
//
// Returns:
//  Array - contains an array of addresses structures.
//           Structure fields:
//             Alias      - String - recipient presentation.
//             Address          - String - found and suitable postal address;
//                                       If the text similar to address is found but
//                                       does not correspond to standards requirements, then such text is written to the Alias field.
//             ErrorDescription - String - error text presentation or an empty row if there are no errors.
Function EmailsFromString(Val String) Export
	
	Result = New Array;
	
	// replace brackets with gaps
	BracketChars = "<>()[]";
	String = ReplaceCharsInStringWithSpaces(String, BracketChars);
	
	// Reduce delimiters to the single kind.
	String = StrReplace(String, ",", ";");
	
	// Break down mailbox-list into mailbox'es.
	ArrayOFAddresses = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(String, ";", True);
	
	// Valid characters for alias (display-name).
	Letters = "abcdefghijklmnopqrstuvwxyz";
	Digits = "0123456789";
	AdditionalChars = "._- ";
	
	// Select alias (display-name) and address (addr-spec) from the (mailbox'a) address row.
	For Each AddressString IN ArrayOFAddresses Do
		
		Alias = "";
		Address = "";
		ErrorDescription = "";
		
		If StrOccurrenceCount(AddressString, "@") <> 1 Then
			Alias = AddressString;
		Else
			// Put everything that does not work as an address to alias.
			For Each Substring IN StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(AddressString, " ") Do
				If IsBlankString(Address) AND EmailAddressMeetsRequirements(Substring) Then
					Address = Substring;
				Else
					Alias = Alias + " " + Substring;
				EndIf;
			EndDo;
		EndIf;
		
		Alias = TrimAll(Alias);
		
		// Checks
		HasProhibitedCharsInAlias = Not StringContainsAllowedCharsOnly(Lower(Alias), Letters + Digits + AdditionalChars);
		AddressDefined = Not IsBlankString(Address);
		StringContainsEmail = Find(AddressString, "@") > 0;
		
		If AddressDefined Then 
			If HasProhibitedCharsInAlias Then
				ErrorDescription = NStr("en='Presentation contains invalid symbols';ru='Представление содержит недопустимые символы'");
			EndIf;
		Else
			If StringContainsEmail Then 
				ErrorDescription = NStr("en='Email address has errors';ru='Адрес электронной почты содержит ошибки'");
			Else
				ErrorDescription = NStr("en='Row does not contain the email address';ru='Строка не содержит адреса электронной почты'");
			EndIf;
		EndIf;	
		
		StructureOfAddress = New Structure("Alias,Address,ErrorDescription", Alias, Address, ErrorDescription);
		Result.Add(StructureOfAddress);
	EndDo;
	
	Return Result;	
	
EndFunction

// Checks email address for match to requirements of standards
// RFC 5321, RFC 5322 and also RFC 5335, RFC 5336  and RFC 3696.
// Moreover, the function restricts special characters usage.
// 
// Parameters:
//  Address - String - checking email.
//
// Returns:
//  Boolean - True if there are no errors.
//
Function EmailAddressMeetsRequirements(Val Address, AllowLocalAddresses = False) Export
	
	// Allowed characters for email.
	Letters = "abcdefghijklmnopqrstuvwxyz";
	Digits = "0123456789";
	SpecChars = ".@_-";
	
	// Check any combinations of special characters.
	If StrLen(SpecChars) > 1 Then
		For Position1 = 1 To StrLen(SpecChars)-1 Do
			Char1 = Mid(SpecChars, Position1, 1);
			For Position2 = Position1 + 1 To StrLen(SpecChars) Do
				Char2 = Mid(SpecChars, Position2, 1);
				Combination1 = Char1 + Char2;
				Combination2 = Char2 + Char1;
				If Find(Address, Combination1) > 0 Or Find(Address, Combination2) > 0 Then
					Return False;
				EndIf;
			EndDo;
		EndDo;
	EndIf;
	
	// check symbol @
	If StrOccurrenceCount(Address, "@") <> 1 Then
		Return False;
	EndIf;
	   
	// check two points in a row
	If Find(Address, "..") > 0 Then
		Return False;
	EndIf;
	
	// Convert address row to the lower register.
	Address = Lower(Address);
	
	// Check valid characters.
	If Not StringContainsAllowedCharsOnly(Address, Letters + Digits + SpecChars) Then
		Return False;
	EndIf;
	
	// Disassemble the address on local-part and domain.
	Position = Find(Address,"@");
	LocalName = Left(Address, Position - 1);
	Domain = Mid(Address, Position + 1);
	
	// Check for fullness and length validity.
	If IsBlankString(LocalName)
	 	Or IsBlankString(Domain)
		Or StrLen(LocalName) > 64
		Or StrLen(Domain) > 255 Then
		
		Return False;
	EndIf;
	
	// Check if there are special characters at the beginning and at the end of address parts.
	If HasCharsLeftRight(LocalName, SpecChars) Or HasCharsLeftRight(Domain, SpecChars) Then
		Return False;
	EndIf;
	
	// Domain must have at least one point.
	If Not AllowLocalAddresses AND Find(Domain,".") = 0 Then
		Return False;
	EndIf;
	
	// There should not be an underscore character in the domain.
	If Find(Domain,"_") > 0 Then
		Return False;
	EndIf;
	
	// Select area (TLD) from domain name.
	TLD = Domain;
	Position = Find(TLD,".");
	While Position > 0 Do
		TLD = Mid(TLD, Position + 1);
		Position = Find(TLD,".");
	EndDo;
	
	// Check domain zone (2 characters minimum, only letters).
	Return AllowLocalAddresses Or StrLen(TLD) >= 2 AND StringContainsAllowedCharsOnly(TLD,Letters);
	
EndFunction

// Checks correctness of the passed string with email addresses.
//
// String format:
//  Z = UserName|[User Name] [<]user@mail_server[>], String = Z[<splitter*>Z]
// 
//  Note: splitter* is any address splitter.
//
// Parameters:
//  EmailAddressString - String - correct string with email addresses.
//
// Returns:
//  Structure
//  State - Boolean - flag that shows whether conversion completed successfully.
//          If conversion completed successfully it contains Value, which is an array of
//          structures with the following keys:
//           Address      - recipient email address;
//           Presentation - recipient name.
//          If conversion failed it contains ErrorMessage - String.
//
// IMPORTANT: The function returns an array of structures, where one field (any field)
//            can be empty. It can be used by various subsystems for mapping user names to
//            email addresses. Therefore it is necessary to check before sending whether email
//            address is filled.
//
Function SplitStringWithEmailAddresses(Val EmailAddressString, RaiseException = True) Export
	
	Result = New Array;
	
	ProhibitedChars = "!#$%^&*()+`~|\/=";
	
	ProhibitedCharsMessage = NStr("en = 'There is a prohibited character %1 in the email address %2'");
	MessageInvalidEmailFormat = NStr("en = 'Incorrect email address %1'");
	
	SubstringArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(EmailAddressString,";",True);
	SubstringArrayToProcess = New Array;
	
	For Each ArrayElement In SubstringArray Do
		If Find(ArrayElement,",") > 0 Then
			AdditionalSubstringArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(EmailAddressString);
			For Each AdditionalArrayElement In AdditionalSubstringArray Do
				SubstringArrayToProcess.Add(AdditionalArrayElement);
			EndDo;
		Else
			SubstringArrayToProcess.Add(ArrayElement);
		EndIf;
	EndDo;
	
	For Each AddressString In SubstringArrayToProcess Do
		
		Index = 1;              // Number of processed character.
		Accumulator = "";       // Character accumulator. After the end of analysis, it passes its 
		                        // value to the full name or to the mail address.
		AddresseeFullName = ""; // Variable that accumulates the addressee name.
		EmailAddress = "";      // Variable that accumulates the email address.
		// 1 - Generating the full name: any allowed characters of the addressee name are expected.
		// 2 - Generating the mail address: any allowed characters of the email address are
		//     expected.
		// 3 - Ending mail address generation: a splitter character or a space character are
		//     expected. 
		ParsingStage = 1; 
		
		While Index <= StrLen(AddressString) Do
			
			Char = Mid(AddressString, Index, 1);
			
			If Char = " " Then
				Index = ?((SkipChars(AddressString, Index, " ") - 1) > Index,
				SkipChars(AddressString, Index, " ") - 1,
				Index);
				If ParsingStage = 1 Then
					AddresseeFullName = AddresseeFullName + Accumulator + " ";
				ElsIf ParsingStage = 2 Then
					EmailAddress = Accumulator;
					ParsingStage = 3;
				EndIf;
				Accumulator = "";
			ElsIf Char = "@" Then
				If ParsingStage = 1 Then
					ParsingStage = 2;
					
					For PCSearchIndex = 1 to StrLen(Accumulator) Do
						If Find(ProhibitedChars, Mid(Accumulator, PCSearchIndex, 1)) > 0 And RaiseException Then
							Raise StringFunctionsClientServer.SubstituteParametersInString(
							 ProhibitedCharsMessage,Mid(Accumulator, PCSearchIndex, 1),AddressString);
						EndIf;
					EndDo;
					
					Accumulator = Accumulator + Char;
				ElsIf ParsingStage = 2 And RaiseException Then
					Raise StringFunctionsClientServer.SubstituteParametersInString(
					 MessageInvalidEmailFormat,AddressString);
				ElsIf ParsingStage = 3 And RaiseException Then
					Raise StringFunctionsClientServer.SubstituteParametersInString(
					 MessageInvalidEmailFormat,AddressString);
				EndIf;
			Else
				If ParsingStage = 2 Or ParsingStage = 3 Then
					If Find(ProhibitedChars, Char) > 0 And RaiseException Then
						Raise StringFunctionsClientServer.SubstituteParametersInString(
						 ProhibitedCharsMessage,Char,AddressString);
					EndIf;
				EndIf;
				
				Accumulator = Accumulator + Char;
			EndIf;
			
			Index = Index + 1;
		EndDo;
		
		If ParsingStage = 1 Then
			AddresseeFullName = AddresseeFullName + Accumulator;
		ElsIf ParsingStage = 2 Then
			EmailAddress = Accumulator;
		EndIf;
		
		If IsBlankString(EmailAddress) And (Not IsBlankString(AddresseeFullName)) And RaiseException Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
			 MessageInvalidEmailFormat,AddresseeFullName);
		ElsIf StrOccurrenceCount(EmailAddress,"@") <> 1 And RaiseException Then 
			Raise StringFunctionsClientServer.SubstituteParametersInString(
			 MessageInvalidEmailFormat,EmailAddress);
		EndIf;
		
		If Not (IsBlankString(AddresseeFullName) And IsBlankString(EmailAddress)) Then
			Result.Add(CheckAndPrepareEmailAddress(AddresseeFullName, EmailAddress));
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

// Function checks whether the entered row with email addresses is entered correctly.
//
// String format:
// Z = UserName|[Name User] [<]user@postal_server[>], String = Z[<separator*>Z].
// 
//   Note.: separator* - any address separator is meant.
//
// Parameters:
// EmailAddressString - String - correct row with mailing addresses.
//
// Returns:
// Structure
// key Status - Boolean - successful or
// unsuccessful conversion in case it is successful, it contains the Value key:
//           Array of structures where.
//                  Recipient Email address.
//                  Presentation   - name
// of the recipient in case of failure contains the ErrorMessage key - String.
//
//  IMPORTANT: Function returns the structures array where
//         one field (any) can be empty. It can
//         be used by the various subsystems
//         for its own match of a user's name to an email address. That is why
//         before the immediate sending it is required to check whether the field of postal addresses is filled in.
//
Function ParseStringWithPostalAddresses(Val EmailAddressString, CallingException = True) Export
	
	Result = New Array;
	
	ProhibitedChars = "!#$%^&*()+`~|\/=";
	
	ProhibitedCharsMessage = NStr("en='Invalid character %1 in the email address %2';ru='Недопустимый символ ""%1"" в адресе электронной почты ""%2""'");
	MessageInvalidEmailFormat = NStr("en='Incorrect email address % 1';ru='Некорректный адрес электронной почты ""%1""'");
	
	SubstringArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(EmailAddressString,";",True);
	SubstringArrayToProcess = New Array;
	
	For Each ArrayElement IN SubstringArray Do
		If Find(ArrayElement,",") > 0 Then
			AdditionalSubstringArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(EmailAddressString);
			For Each AdditionalArrayElement IN AdditionalSubstringArray Do
				SubstringArrayToProcess.Add(AdditionalArrayElement);
			EndDo;
		Else
			SubstringArrayToProcess.Add(ArrayElement);
		EndIf;
	EndDo;
	
	For Each AddressString IN SubstringArrayToProcess Do
		
		IndexOf = 1;               // Number of processed character.
		Accumulator = "";          // Characters accumulator, after analysis it moves either
		// to the full name, or to the postal address.
		FullNameAddressee = "";   // variable accumulate name of addressee.
		MailAddress = "";       // Variable that accumulates
		// email address 1 - generate full name: any available 2 recipient
		// name characters are expected - generate postal address: any available 3 email address
		// characters are expected - finish formatting of another postal address - separator characters or gaps are expected.
		ParsingPhase = 1; 
		
		While IndexOf <= StrLen(AddressString) Do
			
			Char = Mid(AddressString, IndexOf, 1);
			
			If      Char = " " Then
				IndexOf = ? ((SkipSpaces(AddressString, IndexOf, " ") - 1) > IndexOf,
				SkipSpaces(AddressString, IndexOf, " ") - 1,
				IndexOf);
				If      ParsingPhase = 1 Then
					FullNameAddressee = FullNameAddressee + Accumulator + " ";
				ElsIf ParsingPhase = 2 Then
					MailAddress = Accumulator;
					ParsingPhase = 3;
				EndIf;
				Accumulator = "";
			ElsIf Char = "@" Then
				If      ParsingPhase = 1 Then
					ParsingPhase = 2;
					
					For SearchIndexNS = 1 To StrLen(Accumulator) Do
						If Find(ProhibitedChars, Mid(Accumulator, SearchIndexNS, 1)) > 0 AND CallingException Then
							Raise StringFunctionsClientServer.SubstituteParametersInString(
							                  ProhibitedCharsMessage,Mid(Accumulator, SearchIndexNS, 1),AddressString);
						EndIf;
					EndDo;
					
					Accumulator = Accumulator + Char;
				ElsIf ParsingPhase = 2 AND CallingException Then
					Raise StringFunctionsClientServer.SubstituteParametersInString(
					                  MessageInvalidEmailFormat,AddressString);
				ElsIf ParsingPhase = 3 AND CallingException Then
					Raise StringFunctionsClientServer.SubstituteParametersInString(
					                  MessageInvalidEmailFormat,AddressString);
				EndIf;
			Else
				If ParsingPhase = 2 OR ParsingPhase = 3 Then
					If Find(ProhibitedChars, Char) > 0 AND CallingException Then
						Raise StringFunctionsClientServer.SubstituteParametersInString(
						                  ProhibitedCharsMessage,Char,AddressString);
					EndIf;
				EndIf;
				
				Accumulator = Accumulator + Char;
			EndIf;
			
			IndexOf = IndexOf + 1;
		EndDo;
		
		If      ParsingPhase = 1 Then
			FullNameAddressee = FullNameAddressee + Accumulator;
		ElsIf ParsingPhase = 2 Then
			MailAddress = Accumulator;
		EndIf;
		
		If IsBlankString(MailAddress) AND (NOT IsBlankString(FullNameAddressee)) AND CallingException Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
			                  MessageInvalidEmailFormat, FullNameAddressee);
		ElsIf StrOccurrenceCount(MailAddress, "@") <> 1 AND CallingException Then 
			Raise StringFunctionsClientServer.SubstituteParametersInString(
			                  MessageInvalidEmailFormat,MailAddress);
		EndIf;
		
		If Not (IsBlankString(FullNameAddressee) AND IsBlankString(MailAddress)) Then
			Result.Add(CheckAndPrepareMailAddress(FullNameAddressee, MailAddress));
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Functions for work with filters and parameters of dynamic lists.
//

// Find item or filter group by the specified field name or presentation.
//
// Parameters:
//  SearchArea - container with items and filter groups, for example.
//                  List.Filter or group in filter.
//  FieldName       - String - layout field name (not used for groups).
//  Presentation - String - layout field presentation.
//
Function FindFilterItemsAndGroups(Val SearchArea,
									Val FieldName = Undefined,
									Val Presentation = Undefined) Export
	
	If ValueIsFilled(FieldName) Then
		SearchValue = New DataCompositionField(FieldName);
		SearchMethod = 1;
	Else
		SearchMethod = 2;
		SearchValue = Presentation;
	EndIf;
	
	ItemArray = New Array;
	
	FindRecursively(SearchArea.Items, ItemArray, SearchMethod, SearchValue);
	
	Return ItemArray;
	
EndFunction

// Add filter group to the ItemsCollection collection.
//
// Parameters:
//  ItemCollection - container with items and filter groups, for example.
//                      List.Filter.Items or group in the filter.
//  GroupType          - DataCompositionFilterItemsGroupType - group type.
//  Presentation      - String - group presentation.
//
Function CreateGroupOfFilterItems(Val ItemCollection, Presentation, GroupType) Export
	
	If TypeOf(ItemCollection) = Type("DataCompositionFilterItemGroup") Then
		ItemCollection = ItemCollection.Items;
	EndIf;
	
	FilterItemGroup = FindFilterItemByPresentation(ItemCollection, Presentation);
	If FilterItemGroup = Undefined Then
		FilterItemGroup = ItemCollection.Add(Type("DataCompositionFilterItemGroup"));
	Else
		FilterItemGroup.Items.Clear();
	EndIf;
	
	FilterItemGroup.Presentation    = Presentation;
	FilterItemGroup.Application       = DataCompositionFilterApplicationType.Items;
	FilterItemGroup.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	FilterItemGroup.GroupType        = GroupType;
	FilterItemGroup.Use    = True;
	
	Return FilterItemGroup;
	
EndFunction

// Add layout item to layout items container.
//
// Parameters:
//  AreaToAdd - container with items and filter groups, for example.
//                  List.Filter or group in filter.
//  FieldName                 - String - data layout field name (always filled in).
//  RightValue          - arbitrary - comparsion value.
//  ComparisonType            - DataCompositionComparisonType - comparsion type.
//  Presentation           - String - presentation of data layout item.
//  Use           - Boolean - item usage.
//  ViewMode        - DataCompositionSettingsItemViewMode - display mode.
//  UserSettingID - String - see DataLayoutFilter.UserSettingID
//                                                    in the syntax assistant.
//
Function AddCompositionItem(AreaToAdd,
									Val FieldName,
									Val ComparisonType,
									Val RightValue = Undefined,
									Val Presentation  = Undefined,
									Val Use  = Undefined,
									val ViewMode = Undefined,
									val UserSettingID = Undefined) Export
	
	Item = AreaToAdd.Items.Add(Type("DataCompositionFilterItem"));
	Item.LeftValue = New DataCompositionField(FieldName);
	Item.ComparisonType = ComparisonType;
	
	If ViewMode = Undefined Then
		Item.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	Else
		Item.ViewMode = ViewMode;
	EndIf;
	
	If RightValue <> Undefined Then
		Item.RightValue = RightValue;
	EndIf;
	
	If Presentation <> Undefined Then
		Item.Presentation = Presentation;
	EndIf;
	
	If Use <> Undefined Then
		Item.Use = Use;
	EndIf;
	
	// Important: identifier should be
	// set in the end of the item setting,
	// otherwise, it will be copied to the custom settings and it will be partially filled in.
	If UserSettingID <> Undefined Then
		Item.UserSettingID = UserSettingID;
	ElsIf Item.ViewMode <> DataCompositionSettingsItemViewMode.Inaccessible Then
		Item.UserSettingID = FieldName;
	EndIf;
	
	Return Item;
	
EndFunction

// Change filter item with the specified fied name or presentation.
//
// Parameters:
//  FieldName                 - String - data layout field name (always filled in).
//  Presentation           - String - presentation of data layout item.
//  RightValue          - arbitrary - comparsion value.
//  ComparisonType            - DataCompositionComparisonType - comparsion type.
//  Use           - Boolean - item usage.
//  ViewMode        - DataCompositionSettingsItemViewMode - display mode.
//
Function ChangeFilterItems(SearchArea,
								Val FieldName = Undefined,
								Val Presentation = Undefined,
								Val RightValue = Undefined,
								Val ComparisonType = Undefined,
								Val Use = Undefined,
								Val ViewMode = Undefined,
								Val UserSettingID = Undefined) Export
	
	If ValueIsFilled(FieldName) Then
		SearchValue = New DataCompositionField(FieldName);
		SearchMethod = 1;
	Else
		SearchMethod = 2;
		SearchValue = Presentation;
	EndIf;
	
	ItemArray = New Array;
	
	FindRecursively(SearchArea.Items, ItemArray, SearchMethod, SearchValue);
	
	For Each Item IN ItemArray Do
		If FieldName <> Undefined Then
			Item.LeftValue = New DataCompositionField(FieldName);
		EndIf;
		If Presentation <> Undefined Then
			Item.Presentation = Presentation;
		EndIf;
		If Use <> Undefined Then
			Item.Use = Use;
		EndIf;
		If ComparisonType <> Undefined Then
			Item.ComparisonType = ComparisonType;
		EndIf;
		If RightValue <> Undefined Then
			Item.RightValue = RightValue;
		EndIf;
		If ViewMode <> Undefined Then
			Item.ViewMode = ViewMode;
		EndIf;
		If UserSettingID <> Undefined Then
			Item.UserSettingID = UserSettingID;
		EndIf;
	EndDo;
	
	Return ItemArray.Count();
	
EndFunction

// Delete filter items with the specified field name or presentation.
//
// Parameters:
//  DeletionArea - container with items and filter groups, for example.
//                    List.Filter or group in filter.
//  FieldName         - String - layout field name (not used for groups).
//  Presentation   - String - layout field presentation.
//
Procedure DeleteItemsOfFilterGroup(Val DeletionArea, Val FieldName = Undefined, Val Presentation = Undefined) Export
	
	If ValueIsFilled(FieldName) Then
		SearchValue = New DataCompositionField(FieldName);
		SearchMethod = 1;
	Else
		SearchMethod = 2;
		SearchValue = Presentation;
	EndIf;
	
	ItemArray = New Array;
	
	FindRecursively(DeletionArea.Items, ItemArray, SearchMethod, SearchValue);
	
	For Each Item IN ItemArray Do
		If Item.Parent = Undefined Then
			DeletionArea.Items.Delete(Item);
		Else
			Item.Parent.Items.Delete(Item);
		EndIf;
	EndDo;
	
EndProcedure

// Add or replace the existing filter item.
//
// Parameters:
//  WhereToAdd - container with items and filter groups, for example.
//                  List.Filter or group in filter.
//  FieldName                 - String - data layout field name (always filled in).
//  RightValue          - arbitrary - comparsion value.
//  ComparisonType            - DataCompositionComparisonType - comparsion type.
//  Presentation           - String - presentation of data layout item.
//  Use           - Boolean - item usage.
//  ViewMode        - DataCompositionSettingsItemViewMode - display mode.
//  UserSettingID - String - see DataLayoutFilter.UserSettingID
//                                                    in the syntax assistant.
//
Procedure SetFilterItem(WhereToAdd,
								Val FieldName,
								Val RightValue = Undefined,
								Val ComparisonType = Undefined,
								Val Presentation = Undefined,
								Val Use = Undefined,
								Val ViewMode = Undefined,
								Val UserSettingID = Undefined) Export
	
	ModifiedCount = ChangeFilterItems(WhereToAdd, FieldName, Presentation,
							RightValue, ComparisonType, Use, ViewMode, UserSettingID);
	
	If ModifiedCount = 0 Then
		If ComparisonType = Undefined Then
			If TypeOf(RightValue) = Type("Array")
				Or TypeOf(RightValue) = Type("FixedArray")
				Or TypeOf(RightValue) = Type("ValueList") Then
				ComparisonType = DataCompositionComparisonType.InList;
			Else
				ComparisonType = DataCompositionComparisonType.Equal;
			EndIf;
		EndIf;
		If ViewMode = Undefined Then
			ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		EndIf;
		AddCompositionItem(WhereToAdd, FieldName, ComparisonType,
								RightValue, Presentation, Use, ViewMode, UserSettingID);
	EndIf;
	
EndProcedure

// Add or replace the existing item of the dynamic list item.
//
// Parameters:
//   DynamicList - DynamicList - List where the filter should be set.
//   FieldName            - String - Field according to which it is required to set filter.
//   RightValue     - Arbitrary - Filter value.
//       Optional. Default value: Undefined.
//       Warning! It you pass Undefined, then value will not be changed.
//   ComparisonType  - DataCompositionComparisonType - Filter condition.
//   Presentation - String - Presentation of data layout item.
//       Optional. Default value: Undefined.
//       If it is specified that only check box of use with the specified presentation is displayed (value is not displayed).
//       To clear (to select value again), you should pass an empty row.
//   Use - Boolean - Check box of using this filter.
//       Optional. Default value: Undefined.
//   ViewMode - DataCompositionSettingsItemViewMode - Display method of
//                                                                          this filter to user.
//       * DataLayoutSettingItemDisplayMode.QuickAccess - IN the group of quick settings above the list.
//       * DataLayoutSettingsItemDisplayMode.Regular       - IN the list settings  (in the More submenu).
//       * DataLayoutSettingsItemDisplayMode.Unavailable   - Restrict user from changing this filter.
//   UserSettingID - String - Unique identifier of this filter.
//       Used for connection with the custom settings.
//
// See also:
//   Eponymous DataLayoutFilterItem object properties in the syntax helper.
//
Procedure SetFilterDynamicListItem(DynamicList, FieldName,
	RightValue = Undefined,
	ComparisonType = Undefined,
	Presentation = Undefined,
	Use = Undefined,
	ViewMode = Undefined,
	UserSettingID = Undefined) Export
	
	If ViewMode = Undefined Then
		ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	EndIf;
	
	If ViewMode = DataCompositionSettingsItemViewMode.Inaccessible Then
		DynamicFilterList = DynamicList.SettingsComposer.FixedSettings.Filter;
	Else
		DynamicFilterList = DynamicList.SettingsComposer.Settings.Filter;
	EndIf;
	
	SetFilterItem(
		DynamicFilterList,
		FieldName,
		RightValue,
		ComparisonType,
		Presentation,
		Use,
		ViewMode,
		UserSettingID);
	
EndProcedure

// Delete filter group item of the dynamic list.
//
// Parameters:
//  DynamicList - DynamicList - form attribute for which it is required to set filter.
//  FieldName         - String - layout field name (not used for groups).
//  Presentation   - String - layout field presentation.
//
Procedure DeleteGroupsSelectionDynamicListItems(DynamicList, FieldName = Undefined, Presentation = Undefined) Export
	
	DeleteItemsOfFilterGroup(
		DynamicList.SettingsComposer.FixedSettings.Filter,
		FieldName,
		Presentation);
	
	DeleteItemsOfFilterGroup(
		DynamicList.SettingsComposer.Settings.Filter,
		FieldName,
		Presentation);
	
EndProcedure

// Set or update the ParameterName parameter value of the List dynamic list.
//
// Parameters:
//  List          - DynamicList - form attribute for which it is required to set parameter.
//  ParameterName    - String             - dynamic list parameter name.
//  Value        - Arbitrary        - parameter new value.
//  Use   - Boolean             - shows that the parameter is used.
//
Procedure SetDynamicListParameter(List, ParameterName, Value, Use = True) Export
	
	DataCompositionParameterValue = List.Parameters.FindParameterValue(New DataCompositionParameter(ParameterName));
	If DataCompositionParameterValue <> Undefined Then
		If Use AND DataCompositionParameterValue.Value <> Value Then
			DataCompositionParameterValue.Value = Value;
		EndIf;
		If DataCompositionParameterValue.Use <> Use Then
			DataCompositionParameterValue.Use = Use;
		EndIf;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Functions for working with managed forms.
//

// Receives form attribute value.
// Parameters:
// 	Form
//		AttributePath - String, path to data, for example: Object.MonthAccruals.
Function GetFormAttributeByPath(Form, AttributePath) Export
	
	NameArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(AttributePath, ".");
	
	Object        = Form;
	LastField = NameArray[NameArray.Count()-1];
	
	For Ct = 0 To NameArray.Count()-2 Do
		Object = Object[NameArray[Ct]]
	EndDo;
	
	Return Object[LastField];
	
EndFunction

// Sets the value to form attribute.
// Parameters:
// 	Form
// 	AttributePath - String, path to data, for example, Object.Accruals
//		Value
Procedure SetFormAttributeByPath(Form, AttributePath, Value, NotFilledOnly = False) Export
	
	NameArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(AttributePath, ".");
	
	Object        = Form;
	LastField = NameArray[NameArray.Count()-1];
	
	For Ct = 0 To NameArray.Count()-2 Do
		Object = Object[NameArray[Ct]]
	EndDo;
	If Not NotFilledOnly OR Not ValueIsFilled(Object[LastField]) Then
		Object[LastField] = Value;
	EndIf;
	
EndProcedure

// Searches for filter item in collection by the specified presentation.
//
// Parameters:
//  ItemCollection - container with items and filter groups, for example.
//                      List.Filter.Items or group in the filter.
//  Presentation string - group presentation.
// 
Function FindFilterItemByPresentation(ItemCollection, Presentation) Export
	
	ReturnValue = Undefined;
	
	For Each FilterItem IN ItemCollection Do
		If FilterItem.Presentation = Presentation Then
			ReturnValue = FilterItem;
			Break;
		EndIf;
	EndDo;
	
	Return ReturnValue
	
EndFunction

// Sets the PropertyName property of the form item with ItemName name to the Value value.
// Applied when the form item can not be on form because user does not
// have rights to an object, attribute or command.
//
// Parameters:
//  FormItems - FormItems property of the managed form.
//  ItemName   - String       - form item name.
//  PropertyName   - String       - name of the set form item property.
//  Value      - Arbitrary - new item value.
// 
Procedure SetFormItemProperty(FormItems, ItemName, PropertyName, Value) Export
	
	FormItem = FormItems.Find(ItemName);
	If FormItem <> Undefined AND FormItem[PropertyName] <> Value Then
		FormItem[PropertyName] = Value;
	EndIf;
	
EndProcedure 

// Returns value of the PropertyName property of the form item with the ItemName name.
// Applied when the form item can not be on form because user does not
// have rights to an object, attribute or command.
// 
// Parameters:
//  FormItems - FormItems property of the managed form.
//  ItemName   - String       - form item name.
//  PropertyName   - String       - form item property name.
// 
// Returns:
//   Arbitrary - PropertyName property value of the ItemName form item.
// 
Function FormItemPropertyValue(FormItems, ItemName, PropertyName) Export
	
	FormItem = FormItems.Find(ItemName);
	Return ?(FormItem <> Undefined, FormItem[PropertyName], Undefined);
	
EndFunction 

// Outdated.
//
// Returns:
//   UsualGroupRepresentation - UsualGroupRepresentation.WeakSelection.
//
Function CommonGroupLineDisplaying() Export
	
	Return UsualGroupRepresentation.WeakSeparation;
	
EndFunction

// Outdated.
//
// Returns:
//   UsualGroupRepresentation - UsualGroupRepresentation.NonermalSelection.
//
Function UsualGroupRepresentationIndent() Export
	
	Return UsualGroupRepresentation.NormalSeparation;
	
EndFunction

// Outdated.
//
// Returns:
//   UsualGroupRepresentation - UsualGroupRepresentation.StrongSelection.
//
Function UsualGroupRepresentationGroupBox() Export
	
	Return UsualGroupRepresentation.StrongSeparation;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Work with predefined data.
//

// It receives the predefined item reference by its full name.
//   Only those tables are supported that can contain predefined items.:
//   catalogs, characteristic kinds chart, accounts chart and calculation kinds chart.
//
// Parameters:
//   FullPredefinedName - String - Full path to the predefined item including its name.
//     Format is completely equivalent to the PredefinedValue global context function.
//     ForExample:
//       Catalog.ContactInformationKinds.UserEmail
//       ChartOfAccounts.SelfSupporting.Materials
//       ChartOfCalculationTypes.Accruals.PaymentOnSalary
//
// Returns: 
//   AnyRef - Ref of the predefined item.
//   Undefined - If item is not found.
//
Function PredefinedItem(FullPredefinedName) Export
	If Upper(Right(FullPredefinedName, 13)) = ".EmptyRef" Then
		// To receive empty refs, use platform standard function.
		Return PredefinedValue(FullPredefinedName);
	EndIf;
	
#If Not ThinClient AND Not WebClient AND Not ThickClientManagedApplication Then
	Return StandardSubsystemsReUse.PredefinedItem(FullPredefinedName);
#Else
	Return StandardSubsystemsClientReUse.PredefinedItem(FullPredefinedName);
#EndIf
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Other functions
//

// Returns parameters structure template to establish external connection.
// Parameters should be assigned with required values and sent.
// To the CommonUse.EstablishExternalConnection() method.
//
Function ExternalConnectionParameterStructure() Export
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("InfobaseOperationMode", 0);
	ParametersStructure.Insert("InfobaseDirectory", "");
	ParametersStructure.Insert("PlatformServerName", "");
	ParametersStructure.Insert("InfobaseNameAtPlatformServer", "");
	ParametersStructure.Insert("OSAuthentication", False);
	ParametersStructure.Insert("UserName", "");
	ParametersStructure.Insert("UserPassword", "");
	
	Return ParametersStructure;
EndFunction

// Extracts connection parameters from the connection
// with infobase row and passes parameters to structure to establish external connection.
//
Function GetConnectionParametersFromInfobaseConnectionString(Val ConnectionString) Export
	
	Result = ExternalConnectionParameterStructure();
	
	Parameters = StringFunctionsClientServer.GetParametersFromString(ConnectionString);
	
	Parameters.Property("File", Result.InfobaseDirectory);
	Parameters.Property("Srvr", Result.PlatformServerName);
	Parameters.Property("Ref",  Result.InfobaseNameAtPlatformServer);
	
	Result.InfobaseOperationMode = ?(Parameters.Property("File"), 0, 1);
	
	Return Result;
EndFunction

// For the work file mode it returns the full name of directory that contains the infobase.
// If it is client server work mode, then an empty row is returned.
// 
// Parameters:
//  No.
// 
// Returns:
//  String - Directory full name where file infobase is located.
//
Function FileInformationBaseDirectory() Export
	
	ConnectionParameters = StringFunctionsClientServer.GetParametersFromString(InfobaseConnectionString());
	
	If ConnectionParameters.Property("File") Then
		Return ConnectionParameters.File;
	EndIf;
	
	Return "";
EndFunction

// Receives identifier (GetIdentifier()) of the values tree row for the
// specified field value of the tree row.
// Used to hover a cursor in hierarchical lists.
// 
Procedure GetTreeRowIDByFieldValue(FieldName, RowID, TreeItemCollection, RowKey, StopSearch) Export
	
	For Each TreeRow IN TreeItemCollection Do
		
		If StopSearch Then
			Return;
		EndIf;
		
		If TreeRow[FieldName] = RowKey Then
			
			RowID = TreeRow.GetID();
			
			StopSearch = True;
			
			Return;
			
		EndIf;
		
		ItemCollection = TreeRow.GetItems();
		
		If ItemCollection.Count() > 0 Then
			
			GetTreeRowIDByFieldValue(FieldName, RowID, ItemCollection, RowKey, StopSearch);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Replaces invalid characters in XML-string with the specified characters.
// 
// Parameters:
//   Text - String - String where it is required to replace invalid characters.
//   ReplacementChar - String - String for which it is required to exchange invalid character in XML-string.
// 
//  Returns:
//    String - String received after invalid characters in XML-string are replaced.
//
Function ReplaceInadmissibleCharsXML(Val Text, ReplacementChar = " ") Export
	
#If Not WebClient Then
	BeginningPosition = 1;
	Position = FindDisallowedXMLCharacters(Text, BeginningPosition);
	While Position > 0 Do
		DisallowedChar = Mid(Text, Position, 1);
		Text = StrReplace(Text, DisallowedChar, ReplacementChar);
		BeginningPosition = Position + 1;
		Position = FindDisallowedXMLCharacters(Text, BeginningPosition);
	EndDo;
	
	Return Text;
#Else
	// Characters codes from 0 to 2^16-1
	// that are considered invalid by the FindUnacceptableXMLCharacters method: 0-8, 11-12, 14-31, 55296-57343.
	Total = "";
	StringLength = StrLen(Text);
	
	For CharacterNumber = 1 To StringLength Do
		Char = Mid(Text, CharacterNumber, 1);
		CharCode = CharCode(Char);
		
		If CharCode < 9
		 Or CharCode > 10    AND CharCode < 13
		 Or CharCode > 13    AND CharCode < 32
		 Or CharCode > 55295 AND CharCode < 57344 Then
			
			Char = " ";
		EndIf;
		Total = Total + Char;
	EndDo;
	
	Return Total;
#EndIf
	
EndFunction

// Deletes invalid characters in XML-string.
// 
// Parameters:
//  Text - String - String where it is required to delete invalid characters.
// 
// Returns:
//  String - String received during the removal of invalid characters in XML-row.
//
Function DeleteInadmissibleCharsXML(Val Text) Export
	
	Return ReplaceInadmissibleCharsXML(Text, "");
	
EndFunction

// Compares two schedules.
//
// Parameters:
// Schedule1 - JobSchedule - first schedule.
//  Schedule2 - JobSchedule - second schedule.
//
// Return
//  value Boolean - true if schedules are identical, otherwise, false.
//
Function SchedulesAreEqual(Val Schedule1, Val Schedule2) Export
	
	Return String(Schedule1) = String(Schedule2);
	
EndFunction

// Returns main configuration language code, for example, ru.
Function MainLanguageCode() Export
	#If Not ThinClient AND Not WebClient Then
		Return Metadata.DefaultLanguage.LanguageCode;
	#Else
		Return StandardSubsystemsClientReUse.ClientWorkParameters().MainLanguageCode;
	#EndIf
EndFunction

// Returns True if client application is connected to the base via the web server.
// If there is no client application, it returns False.
//
Function ClientConnectedViaWebServer() Export
	
#If Client Or ExternalConnection Then
	InfobaseConnectionString = InfobaseConnectionString();
#Else
	SetPrivilegedMode(True);
	
	InfobaseConnectionString = StandardSubsystemsServer.ClientParametersOnServer(
		).Get("InfobaseConnectionString");
	
	If InfobaseConnectionString = Undefined Then
		Return False; // There is no client application.
	EndIf;
#EndIf
	
	Return Find(Upper(InfobaseConnectionString), "WS=") = 1;
	
EndFunction

// It returns True if the client application is running under Windows OS.
//
// Returns:
//  Boolean. If there is no client application, it returns False.
//
Function IsWindowsClient() Export
	
#If Client Or ExternalConnection Then
	SystemInfo = New SystemInfo;
	
	IsWindowsClient = SystemInfo.PlatformType = PlatformType.Windows_x86
				OR SystemInfo.PlatformType = PlatformType.Windows_x86_64;
#Else
	SetPrivilegedMode(True);
	
	IsWindowsClient = StandardSubsystemsServer.ClientParametersOnServer().Get("IsWindowsClient");
	
	If IsWindowsClient = Undefined Then
		Return False; // There is no client application.
	EndIf;
#EndIf
	
	Return IsWindowsClient;
	
EndFunction

// Returns True if the client application is started managed by Linux OS.
//
// Returns:
//  Boolean. If there is no client application, it returns False.
//
Function IsLinuxClient() Export
	
#If Client Or ExternalConnection Then
	SystemInfo = New SystemInfo;
	
	IsLinuxClient = SystemInfo.PlatformType = PlatformType.Linux_x86
	             OR SystemInfo.PlatformType = PlatformType.Linux_x86_64;
#Else
	SetPrivilegedMode(True);
	
	IsLinuxClient = StandardSubsystemsServer.ClientParametersOnServer().Get("IsLinuxClient");
	
	If IsLinuxClient = Undefined Then
		Return False; // There is no client application.
	EndIf;
#EndIf
	
	Return IsLinuxClient;
	
EndFunction

// Returns True if client application is a Web client.
//
// Returns:
//  Boolean. If there is no client application, it returns False.
//
Function ThisIsWebClient() Export
	
#If WebClient Then
	Return True;
#ElsIf Client Or ExternalConnection Then
	Return False;
#Else
	SetPrivilegedMode(True);
	
	ThisIsWebClient = StandardSubsystemsServer.ClientParametersOnServer().Get("ThisIsWebClient");
	
	If ThisIsWebClient = Undefined Then
		Return False; // There is no client application.
	EndIf;
	
	Return ThisIsWebClient;
#EndIf
	
EndFunction

// Returns True if it is a web client in Mac OS.
Function ThisIsMacOSWebClient() Export
	
#If WebClient Then
	Return CommonUseClientReUse.ThisIsMacOSWebClient();
#ElsIf Client Or ExternalConnection Then
	Return False;
#Else
	SetPrivilegedMode(True);
	
	ThisIsMacOSWebClient = StandardSubsystemsServer.ClientParametersOnServer(
		).Get("ThisIsMacOSWebClient");
	
	If ThisIsMacOSWebClient = Undefined Then
		Return False; // There is no client application.
	EndIf;
	
	Return ThisIsMacOSWebClient;
#EndIf
	
EndFunction

// Returns True if the debugging mode is enabled.
Function DebugMode() Export
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	ApplicationStartParameter = SessionParameters.ClientParametersOnServer.Get("LaunchParameter");
#Else
	ApplicationStartParameter = LaunchParameter;
#EndIf
	
	Return Find(ApplicationStartParameter, "DebugMode") > 0;
EndFunction

// Throws an exception with the Message text if Condition does not equal to True.
// It is used for the code self-diagnostic.
//
// Parameters:
//   Condition                - Boolean - if it is not equal to True, then an exception is thrown.
//   CheckContext       - String - for example, procedure or function name where the check is executed.
//   Message              - String - message type. If it is not specified, then exception is
//                                     thrown with the default message.
//
Procedure Validate(Val Condition, Val Message = "", Val CheckContext = "") Export
	
	If Not DebugMode() Then
		Return;
	EndIf;
	
	If Condition <> True Then
		If IsBlankString(Message) Then
			ErrorMessage = NStr("en='Invalid operation';ru='Недопустимая операция'"); // Assertion failed
		Else
			ErrorMessage = Message;
		EndIf;
		If Not IsBlankString(CheckContext) Then
			ErrorMessage = ErrorMessage + " " +
				StringFunctionsClientServer.SubstituteParametersInString(NStr("en='in %1';ru='in %1'"), CheckContext);
		EndIf;
		Raise ErrorMessage;
	EndIf;
	
EndProcedure

// Throws an exception if the ParameterName parameter value type of
// the ProcedureAndFunctionName procedure or function differs from the expected one.
// For diagnostics of parameters types passed to the procedures and functions of the application interface.
//
// Parameters:
//   ProcedureOrFunctionName - String             - procedure or function name which parameter is checked.
//   ParameterName           - String             - name of the checked procedure or function parameter.
//   ParameterValue      - Arbitrary       - parameter actual value.
//   ExpectedTypes          - TypeDescription, Type - parameter or function type(s).
//   ExpectedPropertyTypes   - Structure          - if expected type - structure,
// you can specify its properties types in this parameter.
//
Procedure CheckParameter(Val ProcedureOrFunctionName, Val ParameterName, Val ParameterValue, 
	Val ExpectedTypes, Val ExpectedPropertyTypes = Undefined) Export
	
	If Not DebugMode() Then
		Return;
	EndIf;
	
	Context = "CommonUseClientServer.CheckParameter";
	Validate(TypeOf(ProcedureOrFunctionName) = Type("String"), 
		NStr("en='ProcedureOrFunctionName parameter value is invalid';ru='Недопустимо значение параметра ИмяПроцедурыИлиФункции'"), Context);
	Validate(TypeOf(ParameterName) = Type("String"), 
		NStr("en='ParameterName parameter value is invalid';ru='Недопустимо значение параметра ИмяПараметра'"), Context);
		
	ThisTypeDescription = TypeOf(ExpectedTypes) = Type("TypeDescription");
	Validate(ThisTypeDescription Or TypeOf(ExpectedTypes) = Type("Type"), 
		NStr("en='ExpectedTypes parameter value is invalid';ru='Недопустимо значение параметра ОжидаемыеТипы'"), Context);
		
	InvalidParameter = NStr("en='Invalid value of the %1 parameter in %2. 
		|Expected: %3; sent value: %4 (%5 type).';ru='Недопустимое значение параметра %1 в %2. 
		|Ожидалось: %3; передано значение: %4 (тип %5).'");
	Validate((ThisTypeDescription AND ExpectedTypes.ContainsType(TypeOf(ParameterValue)))
		Or (NOT ThisTypeDescription AND ExpectedTypes = TypeOf(ParameterValue)), 
		StringFunctionsClientServer.SubstituteParametersInString(InvalidParameter, 
			ParameterName, ProcedureOrFunctionName, ExpectedTypes, 
			?(ParameterValue <> Undefined, ParameterValue, NStr("en='Undefined';ru='Неопределено'")), TypeOf(ParameterValue)));
			
	If TypeOf(ParameterValue) = Type("Structure") AND ExpectedPropertyTypes <> Undefined Then
		
		Validate(TypeOf(ExpectedPropertyTypes) = Type("Structure"), 
			NStr("en='ProcedureOrFunctionName parameter value is invalid';ru='Недопустимо значение параметра ИмяПроцедурыИлиФункции'"), Context);
			
		NoProperty = NStr("en='Invalid parameter value %1 (Structure) in %2. 
		|%3 property was expected in the structure (%4 type).';ru='Недопустимое значение параметра %1 (Структура) в %2. 
		|В структуре ожидалось свойство %3 (тип %4).'");
		InvalidProperty = NStr("en='Invalid %1 property value in %2 parameter (Structure) in %3. 
		|Expected: %4; passed value: %5 (%6 type).';ru='Недопустимое значение свойства %1 в параметре %2 (Структура) в %3. 
		|Ожидалось: %4; передано значение: %5 (тип %6).'");
		For Each Property IN ExpectedPropertyTypes Do
			
			ExpectedPropertyName = Property.Key;
			ExpectedPropertyType = Property.Value;
			PropertyValue = Undefined;
			
			Validate(ParameterValue.Property(ExpectedPropertyName, PropertyValue), 
				StringFunctionsClientServer.SubstituteParametersInString(NoProperty, 
					ParameterName, ProcedureOrFunctionName, ExpectedPropertyName, ExpectedPropertyType));
					
			ThisTypeDescription = TypeOf(ExpectedPropertyType) = Type("TypeDescription");
			Validate((ThisTypeDescription AND ExpectedPropertyType.ContainsType(TypeOf(PropertyValue)))
				Or (NOT ThisTypeDescription AND ExpectedPropertyType = TypeOf(PropertyValue)), 
				StringFunctionsClientServer.SubstituteParametersInString(InvalidProperty, 
					ExpectedPropertyName, ParameterName, ProcedureOrFunctionName, ExpectedPropertyType, 
					?(PropertyValue <> Undefined, PropertyValue, NStr("en='Undefined';ru='Неопределено'")), TypeOf(PropertyValue)));
					
		EndDo;	
	EndIf;		
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Mathematical procedures and functions.

// Proportionally distributes an amount
// according to the specified distribution ratios.
//
// Parameters:
//  DistributedAmount - Number - amount that should be distributed;
//  ArrayOfCoefficients - Array - distribution ratios;
//  Precision - Number - rounding precision during allocation. Not required.
//
// Returns:
//  Array - array which dimension equals to
//           ratios array contains the amounts according to the ratios weight (from the ratios array).
//           If it can not be distributed (amount = 0, ratios quantity =
//           0 or total ratios weight = 0), then the Undefined value is returned.
//
Function DistributeAmountProportionallyToFactors(Val DistributedAmount, Ratios, Val Precision = 2) Export
	
	If Ratios.Count() = 0 Or Not ValueIsFilled(DistributedAmount) Then
		Return Undefined;
	EndIf;
	
	MaxRatioIndex = 0;
	MaxRatio = 0;
	DistributedAmount = 0;
	RatiosAmount  = 0;
	
	For IndexOf = 0 To Ratios.Count() - 1 Do
		Factor = Ratios[IndexOf];
		
		AbsoluteRatioValue = ?(Factor > 0, Factor, -Factor);
		If MaxRatio < AbsoluteRatioValue Then
			MaxRatio = AbsoluteRatioValue;
			MaxRatioIndex = IndexOf;
		EndIf;
		
		RatiosAmount = RatiosAmount + Factor;
	EndDo;
	
	If RatiosAmount = 0 Then
		Return Undefined;
	EndIf;
	
	Result = New Array(Ratios.Count());
	
	For IndexOf = 0 To Ratios.Count() - 1 Do
		Result[IndexOf] = Round(DistributedAmount * Ratios[IndexOf] / RatiosAmount, Precision, 1);
		DistributedAmount = DistributedAmount + Result[IndexOf];
	EndDo;
	
	// Assign rounding errors to ratio with the maximum weight.
	If Not DistributedAmount = DistributedAmount Then
		Result[MaxRatioIndex] = Result[MaxRatioIndex] + DistributedAmount - DistributedAmount;
	EndIf;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Outdated procedures and functions.

// Outdated. You should use PathSeparator.
Function GetSlash(Platform = Undefined) Export
	
	Return PathSeparator(Platform);
	
EndFunction

// Outdated. If the value is False, then you should delete all usages of this function and code branches.
//
Function IsPlatform83WithOutCompatibilityMode() Export
	Return True;
EndFunction

// Outdated. If the value is False, then you should delete all usages of this function and code branches.
//
Function IsPlatform83() Export
	Return True;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// HELPER PROCEDURE AND FUNCTIONS

// Searches for item in collection: values list or array.
//
Function FindInList(List, Item)
	
	Var ItemInList;
	
	If TypeOf(List) = Type("ValueList") Then
		If TypeOf(Item) = Type("ValueListItem") Then
			ItemInList = List.FindByValue(Item.Value);
		Else
			ItemInList = List.FindByValue(Item);
		EndIf;
	EndIf;
	
	If TypeOf(List) = Type("Array") Then
		ItemInList = List.Find(Item);
	EndIf;
	
	Return ItemInList;
	
EndFunction

// Checks that email address does not contain border characters.
// If border characters is used correctly, the procedure deletes them.
//
Function CheckAndPrepareEmailAddress(Val AddresseeFullName, Val EmailAddress)
	
	ProhibitedCharInRecipientName = NStr("en = 'There is a prohibited character in the addressee name.'");
	EmailContainsProhibitedChar = NStr("en = 'There is a prohibited character in the email address.'");
	BorderChars = "<>[]";
	
	EmailAddress      = TrimAll(EmailAddress);
	AddresseeFullName = TrimAll(AddresseeFullName);
	
	If Left(AddresseeFullName, 1) = "<" Then
		If Right(AddresseeFullName, 1) = ">" Then
			AddresseeFullName = Mid(AddresseeFullName, 2, StrLen(AddresseeFullName)-2);
		Else
			Raise ProhibitedCharInRecipientName;
		EndIf;
	ElsIf Left(AddresseeFullName, 1) = "[" Then
		If Right(AddresseeFullName, 1) = "]" Then
			AddresseeFullName = Mid(AddresseeFullName, 2, StrLen(AddresseeFullName)-2);
		Else
			Raise ProhibitedCharInRecipientName;
		EndIf;
	EndIf;
	
	If Left(EmailAddress, 1) = "<" Then
		If Right(EmailAddress, 1) = ">" Then
			EmailAddress = Mid(EmailAddress, 2, StrLen(EmailAddress)-2);
		Else
			Raise EmailContainsProhibitedChar;
		EndIf;
	ElsIf Left(EmailAddress, 1) = "[" Then
		If Right(EmailAddress, 1) = "]" Then
			EmailAddress = Mid(EmailAddress, 2, StrLen(EmailAddress)-2);
		Else
			Raise EmailContainsProhibitedChar;
		EndIf;
	EndIf;
	
	For Index = 1 to StrLen(BorderChars) Do
		If Find(AddresseeFullName, Mid(BorderChars, Index, 1)) <> 0
		 Or Find(EmailAddress, Mid(BorderChars, Index, 1)) <> 0 Then
			Raise EmailContainsProhibitedChar;
		EndIf;
	EndDo;
	
	Return New Structure("Address, Presentation", EmailAddress,AddresseeFullName);
	
EndFunction

// Checks if email address contains framing
// characters if the framing characters are inserted correctly, it removes them.
Function CheckAndPrepareMailAddress(Val FullNameAddressee, Val MailAddress)
	
	ProhibitedCharInRecipientName = NStr("en='Inadmissible character in destination name.';ru='Недопустимый символ в имени адресата.'");
	EmailContainsProhibitedChar = NStr("en='Inadmissible symbol in the mail address';ru='Недопустимый символ в почтовом адресе.'");
	BorderChars = "<>[]";
	
	MailAddress     = TrimAll(MailAddress);
	FullNameAddressee = TrimAll(FullNameAddressee);
	
	If Left(FullNameAddressee, 1) = "<" Then
		If Right(FullNameAddressee, 1) = ">" Then
			FullNameAddressee = Mid(FullNameAddressee, 2, StrLen(FullNameAddressee)-2);
		Else
			Raise ProhibitedCharInRecipientName;
		EndIf;
	ElsIf Left(FullNameAddressee, 1) = "[" Then
		If Right(FullNameAddressee, 1) = "]" Then
			FullNameAddressee = Mid(FullNameAddressee, 2, StrLen(FullNameAddressee)-2);
		Else
			Raise ProhibitedCharInRecipientName;
		EndIf;
	EndIf;
	
	If Left(MailAddress, 1) = "<" Then
		If Right(MailAddress, 1) = ">" Then
			MailAddress = Mid(MailAddress, 2, StrLen(MailAddress)-2);
		Else
			Raise EmailContainsProhibitedChar;
		EndIf;
	ElsIf Left(MailAddress, 1) = "[" Then
		If Right(MailAddress, 1) = "]" Then
			MailAddress = Mid(MailAddress, 2, StrLen(MailAddress)-2);
		Else
			Raise EmailContainsProhibitedChar;
		EndIf;
	EndIf;
	
	For IndexOf = 1 To StrLen(BorderChars) Do
		If Find(FullNameAddressee, Mid(BorderChars, IndexOf, 1)) <> 0
		 OR Find(MailAddress,     Mid(BorderChars, IndexOf, 1)) <> 0 Then
			Raise EmailContainsProhibitedChar;
		EndIf;
	EndDo;
	
	Return New Structure("Address, Presentation", MailAddress,FullNameAddressee);
	
EndFunction

// Shifts a position marker while the current character is the SkippedChar.
// Returns number of marker position.
//
Function SkipChars(Val String,
                   Val CurrentIndex,
                   Val SkippedChar)
	
	Result = CurrentIndex;
	
	// Removes skipped characters, if any
	While CurrentIndex < StrLen(String) Do
		If Mid(String, CurrentIndex, 1) <> SkippedChar Then
			Return CurrentIndex;
		EndIf;
		CurrentIndex = CurrentIndex + 1;
	EndDo;
	
	Return CurrentIndex;
	
EndFunction

// Moves the position marker until the
// character occurs The character returns the number of position in row to which marker is set.
//
Function SkipSpaces(Val String,
                          Val CurrentIndex,
                          Val SkippedChar)
	
	Result = CurrentIndex;
	
	// Remove extra spaces if any.
	While CurrentIndex < StrLen(String) Do
		If Mid(String, CurrentIndex, 1) <> SkippedChar Then
			Return CurrentIndex;
		EndIf;
		CurrentIndex = CurrentIndex + 1;
	EndDo;
	
	Return CurrentIndex;
	
EndFunction

Procedure FindRecursively(ItemCollection, ItemArray, SearchMethod, SearchValue)
	
	For Each FilterItem IN ItemCollection Do
		
		If TypeOf(FilterItem) = Type("DataCompositionFilterItem") Then
			
			If SearchMethod = 1 Then
				If FilterItem.LeftValue = SearchValue Then
					ItemArray.Add(FilterItem);
				EndIf;
			ElsIf SearchMethod = 2 Then
				If FilterItem.Presentation = SearchValue Then
					ItemArray.Add(FilterItem);
				EndIf;
			EndIf;
		Else
			
			FindRecursively(FilterItem.Items, ItemArray, SearchMethod, SearchValue);
			
			If SearchMethod = 2 AND FilterItem.Presentation = SearchValue Then
				ItemArray.Add(FilterItem);
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function ReplaceCharsInStringWithSpaces(String, CharsToReplace)
	Result = String;
	For Position = 1 To StrLen(Chars) Do
		Result = StrReplace(Result, Mid(CharsToReplace, Position, 1), " ");
	EndDo;
	Return Result;
EndFunction

Function HasCharsLeftRight(String, CharsToCheck)
	For Position = 1 To StrLen(CharsToCheck) Do
		Char = Mid(CharsToCheck, Position, 1);
		CharFound = (Left(String,1) = Char) Or (Right(String,1) = Char);
		If CharFound Then
			Return True;
		EndIf;
	EndDo;
	Return False;
EndFunction

Function StringContainsAllowedCharsOnly(String, AllowedChars)
	CharacterArray = New Array;
	For Position = 1 To StrLen(AllowedChars) Do
		CharacterArray.Add(Mid(AllowedChars,Position,1));
	EndDo;
	
	For Position = 1 To StrLen(String) Do
		If CharacterArray.Find(Mid(String, Position, 1)) = Undefined Then
			Return False;
		EndIf;
	EndDo;
	
	Return True;
EndFunction

#EndRegion
