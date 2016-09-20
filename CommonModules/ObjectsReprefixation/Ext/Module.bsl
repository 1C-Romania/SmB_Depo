////////////////////////////////////////////////////////////////////////////////
// Subsystem "Objects prefixation".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Sets a new infobase prefix and changes codes and numbers of objects according to the new prefix and code/number format.
// Only objects created in the current info base are to be processed.
// Object creation location is determined by its number or code prefix.
//
//  Parameters:
//  NewIBPrefix - String - New infobase prefix to be set. 
//  ReprefixationBeginOfPeriod - Date - Date from which a new infobase prefix will be set
//                                 for documents, business processes and tasks.
//  LastIBPrefix - String - Infobase prefix that was set previously.
//                                 Setting the variable value makes sense
//                                 only if IB prefix value is lost,
//                                 for example, when switching from the local mode to the service model.
//                                 And also if object numbers and codes have
//                                 a non-standard format that differs from SSL format.
//  ObjectsProcessed - Number - Number of objects for which a number or code was
//                               changed returns to this parameter.
//
Procedure SetIBPrefixAndReprefixAllObjectsCreatedInThisIB(
									Val NewIBPrefix,
									Val ReprefixationBeginOfPeriod = Undefined,
									Val LastIBPrefix = Undefined,
									ObjectsProcessed = 0
	) Export
	
	ServiceSetIBPrefixAndReprefixAllObjectsCreatedInThisIB(NewIBPrefix, ReprefixationBeginOfPeriod, LastIBPrefix, ObjectsProcessed);
	
EndProcedure

// Sets a new infobase prefix and changes codes and numbers of objects according to the new prefix and code/number format.
// All objects are to be processed no matter in which info base the object was created.
// Object creation location is determined by its number or code prefix.
//
//  Parameters:
//  NewIBPrefix - String - New infobase prefix to be set.
//  ReprefixationBeginOfPeriod - Date - Date from which a new infobase prefix will be set
//                                 for documents, business processes and tasks.
//  LastIBPrefix - String - Infobase prefix that was set previously.
//                                 Setting the variable value makes sense
//                                 only if IB prefix value is lost,
//                                 for example, when switching from the local mode to the service model.
//                                 And also if object numbers and codes have
//                                 a non-standard format that differs from SSL format.
//  ObjectsProcessed - Number - Number of objects for which a number or code was
//                               changed returns to this parameter.
//
Procedure SetIBPrefixAndReprefixAllObjects(
									Val NewIBPrefix,
									Val ReprefixationBeginOfPeriod = Undefined,
									Val LastIBPrefix = Undefined,
									ObjectsProcessed = 0
	) Export
	
	ServiceSetIBPrefixAndReprefixAllObjects(NewIBPrefix, ReprefixationBeginOfPeriod, LastIBPrefix, ObjectsProcessed);
	
EndProcedure

// Sets a new info base prefix and creates
// one object for each data type with new info base prefix and SSL number/code format.
// Only objects created in the current info base are to be processed.
// Object creation location is determined by its number or code prefix.
//
//  Parameters:
//  NewIBPrefix - String - New infobase prefix to be set.
//  ReprefixationBeginOfPeriod - Date - Date from which data will be analyzed.
//  LastIBPrefix - String - Infobase prefix that was set previously.
//                          Setting the variable value makes sense
//                          only if IB prefix value is lost,
//                          for example, when switching from the local mode to the service model.
//                          And also if object numbers and codes have
//                          a non-standard format that differs from SSL format.
//  ObjectsProcessed - Number - Number of created objects is returned to the parameter.
//
Procedure SetIBPrefixAndCreateObjects(
									Val NewIBPrefix,
									Val ReprefixationBeginOfPeriod = Undefined,
									Val LastIBPrefix = Undefined,
									ObjectsProcessed = 0
	) Export
	
	ServiceSetIBPrefixAndCreateObjects(NewIBPrefix, ReprefixationBeginOfPeriod, LastIBPrefix, ObjectsProcessed);
	
EndProcedure

// Sets a new info base prefix and changes a
// code or number of last actual object for each data type.
// Only objects created in the current info base are to be processed.
// Object creation location is determined by its number or code prefix.
//
// Parameters:
//  NewIBPrefix - String - New infobase prefix to be set.
//  ReprefixationBeginOfPeriod - Date - Date from which data will be analyzed.
//  LastIBPrefix - String - Infobase prefix that was set previously.
//                          Setting the variable value makes sense
//                          only if IB prefix value is lost,
//                          for example, when switching from the local mode to the service model.
//                          And also if object numbers and codes have
//                          a non-standard format that differs from SSL format.
//  ObjectsProcessed - Number - Number of changed parameters is returned to this parameter.
//
Procedure SetIBPrefixAndReprefixLastObjects(
									Val NewIBPrefix,
									Val ReprefixationBeginOfPeriod = Undefined,
									Val LastIBPrefix = Undefined,
									ObjectsProcessed = 0
	) Export
	
	ServiceSetIBPrefixAndReprefixLastObjects(NewIBPrefix, ReprefixationBeginOfPeriod, LastIBPrefix, ObjectsProcessed);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure ServiceSetIBPrefixAndReprefixAllObjectsCreatedInThisIB(
									Val NewPrefix,
									Val FromDate = Undefined,
									Val PreviousInfobasePrefix = Undefined,
									ProcessedObjectsCounter = 0)
	
	If TransactionActive() Then
		
		Raise NStr("en='Infobase prefix modification can not be performed in the transaction.';ru='Изменение префикса информационной базы не может выполняться в транзакции.'");
		
	ElsIf Not Users.InfobaseUserWithFullAccess() Then
		
		Raise NStr("en='Insufficient rights to change a prefix of the infobase.';ru='Недостаточно прав для изменения префикса информационной базы.'");
		
	EndIf;
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		SetPrivilegedMode(True);
	EndIf;
	
	FromDate = ?(FromDate = Date('00010101'), Undefined, FromDate);
	
	StandardPrefix = (PreviousInfobasePrefix = Undefined);
	
	ProcessedObjectsCounter = 0;
	
	If StandardPrefix Then
		
		SetNewPrefixAndPerformDataProcessingWithStandardCodeFormat(ProcessedObjectsCounter, NewPrefix, FromDate, PreviousInfobasePrefix);
		
	Else
		
		SetNewPrefixAndPerformDataProcessingWithNonstandardCodeFormat(ProcessedObjectsCounter, NewPrefix, FromDate, PreviousInfobasePrefix);
		
	EndIf;
	
EndProcedure

Procedure ServiceSetIBPrefixAndReprefixAllObjects(
									Val NewPrefix,
									Val FromDate = Undefined,
									Val PreviousInfobasePrefix = Undefined,
									ProcessedObjectsCounter = 0)
	
	If TransactionActive() Then
		
		Raise NStr("en='Infobase prefix modification can not be performed in the transaction.';ru='Изменение префикса информационной базы не может выполняться в транзакции.'");
		
	ElsIf Not Users.InfobaseUserWithFullAccess() Then
		
		Raise NStr("en='Insufficient rights to change a prefix of the infobase.';ru='Недостаточно прав для изменения префикса информационной базы.'");
		
	EndIf;
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		SetPrivilegedMode(True);
	EndIf;
	
	FromDate = ?(FromDate = Date('00010101'), Undefined, FromDate);
	
	StandardPrefix = (PreviousInfobasePrefix = Undefined);
	
	ProcessedObjectsCounter = 0;
	
	If StandardPrefix Then
		
		SetNewPrefixAndPerformDataProcessingWithStandardCodeFormat(ProcessedObjectsCounter, NewPrefix, FromDate,, True);
		
	Else
		
		SetNewPrefixAndPerformDataProcessingWithNonstandardCodeFormat(ProcessedObjectsCounter, NewPrefix, FromDate,, True);
		
	EndIf;
	
EndProcedure

Procedure ServiceSetIBPrefixAndCreateObjects(
									Val NewPrefix,
									Val FromDate = Undefined,
									Val PreviousInfobasePrefix = Undefined,
									ProcessedObjectsCounter = 0)
	
	ProcessedObjectsCounter = 0;
	
	SetIBPrefixAndCreateChangeObjects(ProcessedObjectsCounter, NewPrefix, FromDate, PreviousInfobasePrefix, False);
	
EndProcedure

Procedure ServiceSetIBPrefixAndReprefixLastObjects(
									Val NewPrefix,
									Val FromDate = Undefined,
									Val PreviousInfobasePrefix = Undefined,
									ProcessedObjectsCounter = 0)
	
	ProcessedObjectsCounter = 0;
	
	SetIBPrefixAndCreateChangeObjects(ProcessedObjectsCounter, NewPrefix, FromDate, PreviousInfobasePrefix, True);
	
EndProcedure

//

Procedure SetNewPrefixAndPerformDataProcessingWithNonstandardCodeFormat(
									ProcessedObjectsCounter,
									Val NewPrefix,
									Val FromDate,
									Val PreviousInfobasePrefix = Undefined,
									Val ProcessAllData = False
									)
	
	CheckPrefixSetPossibility();
	
	StandardPrefix = False;
	
	If PreviousInfobasePrefix = Undefined Then
		
		WhenDeterminingPrefixInformationBase(PreviousInfobasePrefix);
		
		SupplementStringWithZerosOnTheLeft(PreviousInfobasePrefix, 2);
		
	EndIf;
	
	Try
		
		SetIBPrefix(NewPrefix);
		
		ExternalExclusiveMode = ExclusiveMode();
		If Not ExternalExclusiveMode Then
			CommonUse.LockInfobase(False);
		EndIf;
		
		For Each ObjectDescription IN MetadataUsedInfobasePrefix() Do
			
			Selection = DataSelection(
						ObjectDescription.ObjectName,
						FromDate,
						ObjectDescription.ThisIsDocument,
						StandardPrefix,
						PreviousInfobasePrefix,
						ProcessAllData);
			
			If Selection.IsEmpty() Then
				Continue;
			EndIf;
			
			Selection = Selection.Select();
			
			While Selection.Next() Do
				
				// {Filter: By object creation location}.
				If Not ProcessAllData Then
					
					ObjectFullPrefix = FullPrefix(Selection.Code);
					
					If Not IsBlankString(ObjectFullPrefix)
						AND Find(ObjectFullPrefix, PreviousInfobasePrefix) = 0 Then
						Continue; // Process objects created only in the current info base.
					EndIf;
					
				EndIf;
				
				Object = Selection.Ref.GetObject();
				
				If ObjectDescription.ThisIsDocument Then
					
					Object.SetNewNumber();
					
					CodeFormat = Object.Number;
					
				Else
					
					Object.SetNewCode();
					
					CodeFormat = Object.Code;
					
				EndIf;
				
				// {Handler: OnChangeNumber} Start
				StandardProcessing = True;
				BasicCode = "";
				
				If ObjectDescription.ThisIsDocument Then
					
					ObjectPrefixationOverridable.OnNumberChange(Object, Selection.Code, BasicCode, StandardProcessing);
					
				Else
					
					ObjectPrefixationOverridable.OnCodeChange(Object, Selection.Code, BasicCode, StandardProcessing);
					
				EndIf;
				
				If StandardProcessing = True Then
					
					CodeNew = ObjectNewCode(CodeFormat, Selection.Code, ObjectDescription.ThisIsDocument, Object);
					
				Else
					
					CodeNew = NewCodeBaseObjectCodeu(CodeFormat, BasicCode, ObjectDescription.ThisIsDocument, Object);
					
				EndIf;
				// {Handler: OnChangeNumber} End
				
				ObjectModified = (Selection.Code <> CodeNew);
				
				If ObjectModified Then
					
					Object[?(ObjectDescription.ThisIsDocument, "Number", "Code")] = CodeNew;
					
					Object.DataExchange.Load = True;
					Object.Write();
					
					IncreaseProcessedObjectsCounter(ProcessedObjectsCounter);
					
				EndIf;
				
			EndDo;
			
		EndDo;
		
		If Not ExternalExclusiveMode Then
			CommonUse.UnlockInfobase();
		EndIf;
		
	Except
		
		If Not ExternalExclusiveMode Then
			CommonUse.UnlockInfobase();
		EndIf;
		
		SetIBPrefix(PreviousInfobasePrefix);
		
		WriteLogEvent(EventLogMonitorMessageTextPereprefixionObjects(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

Procedure SetNewPrefixAndPerformDataProcessingWithStandardCodeFormat(
									ProcessedObjectsCounter,
									Val NewPrefix,
									Val FromDate,
									Val PreviousInfobasePrefix = Undefined,
									Val ProcessAllData = False
									)
	
	CheckPrefixSetPossibility();
	
	NewPrefixComplete = StringFunctionsClientServer.SupplementString(NewPrefix, 2);
	
	StandardPrefix = True;
	
	If PreviousInfobasePrefix = Undefined Then
		
		WhenDeterminingPrefixInformationBase(PreviousInfobasePrefix);
		
		SupplementStringWithZerosOnTheLeft(PreviousInfobasePrefix, 2);
		
	EndIf;
	
	Try
		
		SetIBPrefix(NewPrefix);
		
		ExternalExclusiveMode = ExclusiveMode();
		If Not ExternalExclusiveMode Then
			CommonUse.LockInfobase(False);
		EndIf;
		
		// Prefixation by infobase prefix.
		For Each ObjectDescription IN MetadataUsingOnlyPrefixInformationBase() Do
			
			SetNewPrefix(
							2,
							ObjectDescription,
							FromDate,
							PreviousInfobasePrefix,
							ProcessAllData,
							NewPrefixComplete,
							ProcessedObjectsCounter);
			
		EndDo;
		
		// Prefixation by infobase prefix and company.
		For Each ObjectDescription IN MetadataUsingPrefixInformationBaseAndCompanies() Do
			
			SetNewPrefix(
							4,
							ObjectDescription,
							FromDate,
							PreviousInfobasePrefix,
							ProcessAllData,
							NewPrefixComplete,
							ProcessedObjectsCounter);
			
		EndDo;
		
		If Not ExternalExclusiveMode Then
			CommonUse.UnlockInfobase();
		EndIf;
		
	Except
		
		If Not ExternalExclusiveMode Then
			CommonUse.UnlockInfobase();
		EndIf;
		
		SetIBPrefix(PreviousInfobasePrefix);
		
		WriteLogEvent(EventLogMonitorMessageTextPereprefixionObjects(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

// For an internal use.
//
Procedure SetIBPrefixAndCreateChangeObjects(
									ProcessedObjectsCounter,
									Val NewPrefix,
									Val FromDate,
									Val PreviousInfobasePrefix = Undefined,
									Val ProcessLastObjects = False
									
	)
	
	CheckPrefixSetPossibility();
	
	FromDate = ?(FromDate = Date('00010101'), Undefined, FromDate);
	
	StandardPrefix = (PreviousInfobasePrefix = Undefined);
	
	ProcessAllData = False;
	
	If TransactionActive() Then
		
		Raise NStr("en='Infobase prefix modification can not be performed in the transaction.';ru='Изменение префикса информационной базы не может выполняться в транзакции.'");
		
	ElsIf Not Users.InfobaseUserWithFullAccess() Then
		
		Raise NStr("en='Insufficient rights to change a prefix of the infobase.';ru='Недостаточно прав для изменения префикса информационной базы.'");
		
	EndIf;
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		SetPrivilegedMode(True);
	EndIf;
	
	If PreviousInfobasePrefix = Undefined Then
		
		WhenDeterminingPrefixInformationBase(PreviousInfobasePrefix);
		
		SupplementStringWithZerosOnTheLeft(PreviousInfobasePrefix, 2);
		
	EndIf;
	
	Try
		
		SetIBPrefix(NewPrefix);
		
		ExternalExclusiveMode = ExclusiveMode();
		If Not ExternalExclusiveMode Then
			CommonUse.LockInfobase(False);
		EndIf;
		
		// Prefixation by infobase prefix.
		For Each ObjectDescription IN MetadataUsingOnlyPrefixInformationBase() Do
			
			Selection = DataSelection(
						ObjectDescription.ObjectName,
						FromDate,
						ObjectDescription.ThisIsDocument,
						StandardPrefix,
						PreviousInfobasePrefix,
						ProcessAllData);
			
			If Selection.IsEmpty() Then
				Continue;
			EndIf;
			
			Objects = New ValueTable;
			Objects.Columns.Add("Code");
			Objects.Columns.Add("Date");
			Objects.Columns.Add("Period");
			Objects.Columns.Add("Object");
			
			Selection = Selection.Select();
			
			While Selection.Next() Do
				
				// {Filter: By object creation location for a non-standard prefix}.
				If Not ProcessAllData
					AND Not StandardPrefix Then
					
					ObjectFullPrefix = FullPrefix(Selection.Code);
					
					If Not IsBlankString(ObjectFullPrefix)
						AND Find(ObjectFullPrefix, PreviousInfobasePrefix) = 0 Then
						Continue; // Process objects created only in the current info base.
					EndIf;
					
				EndIf;
				
				TableRow = Objects.Add();
				TableRow.Code = NumericalObjectCode(Selection.Code);
				TableRow.Date = Selection.Date;
				TableRow.Period = PeriodDate(Selection.Date, ObjectDescription.NumberPeriodicity);
				TableRow.Object = Selection.Ref;
				
			EndDo;
			
			If Objects.Count() > 0 Then
				
				If ProcessLastObjects Then
					
					Objects.Sort("Period Desc, Code Desc");
					
					Object = Objects[0]["Object"].GetObject();
					
					CodePrevious = Object[?(ObjectDescription.ThisIsDocument, "Number", "Code")];
					
					If ObjectDescription.ThisIsDocument Then
						
						Object.SetNewNumber();
						
						CodeFormat = Object.Number;
						
					Else
						
						Object.SetNewCode();
						
						CodeFormat = Object.Code;
						
					EndIf;
					
					If StandardPrefix Then
						
						CodeNew = ObjectNewCode(CodeFormat, CodePrevious, ObjectDescription.ThisIsDocument, Object);
						
					Else
						
						// {Handler: OnChangeNumber} Start
						StandardProcessing = True;
						BasicCode = "";
						
						If ObjectDescription.ThisIsDocument Then
							
							ObjectPrefixationOverridable.OnNumberChange(Object, CodePrevious, BasicCode, StandardProcessing);
							
						Else
							
							ObjectPrefixationOverridable.OnCodeChange(Object, CodePrevious, BasicCode, StandardProcessing);
							
						EndIf;
						
						If StandardProcessing = True Then
							
							CodeNew = ObjectNewCode(CodeFormat, CodePrevious, ObjectDescription.ThisIsDocument, Object);
							
						Else
							
							CodeNew = NewCodeBaseObjectCodeu(CodeFormat, BasicCode, ObjectDescription.ThisIsDocument, Object);
							
						EndIf;
						// {Handler: OnChangeNumber} End
						
					EndIf;
					
					ObjectModified = (CodePrevious <> CodeNew);
					
					If ObjectModified Then
						
						Object[?(ObjectDescription.ThisIsDocument, "Number", "Code")] = CodeNew;
						
						Object.DataExchange.Load = True;
						Object.Write();
						
						IncreaseProcessedObjectsCounter(ProcessedObjectsCounter);
						
					EndIf;
					
				Else // Creating new objects
					
					Objects.Sort("Period Desc, Code Desc");
					
					MaximumCode = Objects[0]["Code"];
					
					Objects.Sort("Date Desc");
					
					MaximumDate = Objects[0]["Date"];
					
					Object = CreateObject(ObjectDescription);
					
					If ObjectDescription.ThisIsDocument Then
						
						Object.Date = MaximumDate + 1;
						Object.SetNewNumber();
						
						CodeFormat = Object.Number;
						
					Else
						
						Object.SetNewCode();
						
						CodeFormat = Object.Code;
						
					EndIf;
					
					CodeNew = ObjectNewCode(CodeFormat, MaximumCode + 1, ObjectDescription.ThisIsDocument, Object);
					
					Object[?(ObjectDescription.ThisIsDocument, "Number", "Code")] = CodeNew;
					
					Object.DataExchange.Load = True;
					Object.Write();
					
					IncreaseProcessedObjectsCounter(ProcessedObjectsCounter);
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
		// Prefixation by infobase prefix and company.
		For Each ObjectDescription IN MetadataUsingPrefixInformationBaseAndCompanies() Do
			
			Selection = DataSelection(
						ObjectDescription.ObjectName,
						FromDate,
						ObjectDescription.ThisIsDocument,
						StandardPrefix,
						PreviousInfobasePrefix,
						ProcessAllData,
						True);
			
			If Selection.IsEmpty() Then
				Continue;
			EndIf;
			
			CompanyWithoutPrefix = "{CompanyWithoutPrefix}";
			
			Objects = New ValueTable;
			Objects.Columns.Add("Code");
			Objects.Columns.Add("Date");
			Objects.Columns.Add("Period");
			Objects.Columns.Add("Object");
			
			Group = New Map;
			Group.Insert(CompanyWithoutPrefix, Objects);
			
			Selection = Selection.Select();
			
			While Selection.Next() Do
				
				// {Filter: By object creation location for a non-standard prefix}.
				If Not ProcessAllData
					AND Not StandardPrefix Then
					
					ObjectFullPrefix = FullPrefix(Selection.Code);
					
					If Not IsBlankString(ObjectFullPrefix)
						AND Find(ObjectFullPrefix, PreviousInfobasePrefix) = 0 Then
						Continue; // Process objects created only in the current info base.
					EndIf;
					
				EndIf;
				
				If Selection.CompanyPrefixSpecified Then
					
					If Group[Selection.Company] = Undefined Then
						
						Objects = New ValueTable;
						Objects.Columns.Add("Code");
						Objects.Columns.Add("Date");
						Objects.Columns.Add("Period");
						Objects.Columns.Add("Object");
						
						TableRow = Objects.Add();
						TableRow.Code = NumericalObjectCode(Selection.Code);
						TableRow.Date = Selection.Date;
						TableRow.Period = PeriodDate(Selection.Date, ObjectDescription.NumberPeriodicity);
						TableRow.Object = Selection.Ref;
						
						Group.Insert(Selection.Company, Objects);
						
					Else
						
						TableRow = Group[Selection.Company].Add();
						TableRow.Code = NumericalObjectCode(Selection.Code);
						TableRow.Date = Selection.Date;
						TableRow.Period = PeriodDate(Selection.Date, ObjectDescription.NumberPeriodicity);
						TableRow.Object = Selection.Ref;
						
					EndIf;
					
				Else
					
					TableRow = Group[CompanyWithoutPrefix].Add();
					TableRow.Code = NumericalObjectCode(Selection.Code);
					TableRow.Date = Selection.Date;
					TableRow.Period = PeriodDate(Selection.Date, ObjectDescription.NumberPeriodicity);
					TableRow.Object = Selection.Ref;
					
				EndIf;
				
			EndDo;
			
			For Each GroupItem IN Group Do
				
				Objects = GroupItem.Value;
				Company = GroupItem.Key;
				
				If Objects.Count() > 0 Then
					
					If ProcessLastObjects Then
						
						Objects.Sort("Period Desc, Code Desc");
						
						Object = Objects[0]["Object"].GetObject();
						
						CodePrevious = Object[?(ObjectDescription.ThisIsDocument, "Number", "Code")];
						
						If ObjectDescription.ThisIsDocument Then
							
							Object.SetNewNumber();
							
							CodeFormat = Object.Number;
							
						Else
							
							Object.SetNewCode();
							
							CodeFormat = Object.Code;
							
						EndIf;
						
						If StandardPrefix Then
							
							CodeNew = ObjectNewCode(CodeFormat, CodePrevious, ObjectDescription.ThisIsDocument, Object);
							
						Else
							
							// {Handler: OnChangeNumber} Start
							StandardProcessing = True;
							BasicCode = "";
							
							If ObjectDescription.ThisIsDocument Then
								
								ObjectPrefixationOverridable.OnNumberChange(Object, CodePrevious, BasicCode, StandardProcessing);
								
							Else
								
								ObjectPrefixationOverridable.OnCodeChange(Object, CodePrevious, BasicCode, StandardProcessing);
								
							EndIf;
							
							If StandardProcessing = True Then
								
								CodeNew = ObjectNewCode(CodeFormat, CodePrevious, ObjectDescription.ThisIsDocument, Object);
								
							Else
								
								CodeNew = NewCodeBaseObjectCodeu(CodeFormat, BasicCode, ObjectDescription.ThisIsDocument, Object);
								
							EndIf;
							// {Handler: OnChangeNumber} End
							
						EndIf;
						
						ObjectModified = (CodePrevious <> CodeNew);
						
						If ObjectModified Then
							
							Object[?(ObjectDescription.ThisIsDocument, "Number", "Code")] = CodeNew;
							
							Object.DataExchange.Load = True;
							Object.Write();
							
							IncreaseProcessedObjectsCounter(ProcessedObjectsCounter);
							
						EndIf;
						
					Else
						
						Objects.Sort("Period Desc, Code Desc");
						
						MaximumCode = Objects[0]["Code"];
						
						Objects.Sort("Date Desc");
						
						MaximumDate = Objects[0]["Date"];
						
						Object = CreateObject(ObjectDescription);
						
						Object.Company = ?(Company = CompanyWithoutPrefix, Undefined, Company);
						
						If ObjectDescription.ThisIsDocument Then
							
							Object.Date = MaximumDate + 1;
							
							Object.SetNewNumber();
							
							CodeFormat = Object.Number;
							
						Else
							
							Object.SetNewCode();
							
							CodeFormat = Object.Code;
							
						EndIf;
						
						CodeNew = ObjectNewCode(CodeFormat, MaximumCode + 1, ObjectDescription.ThisIsDocument, Object);
						
						Object[?(ObjectDescription.ThisIsDocument, "Number", "Code")] = CodeNew;
						
						Object.DataExchange.Load = True;
						Object.Write();
						
						IncreaseProcessedObjectsCounter(ProcessedObjectsCounter);
						
					EndIf;
					
				EndIf;
				
			EndDo;
			
		EndDo;
		
		If Not ExternalExclusiveMode Then
			CommonUse.UnlockInfobase();
		EndIf;
		
	Except
		
		If Not ExternalExclusiveMode Then
			CommonUse.UnlockInfobase();
		EndIf;
		
		SetIBPrefix(PreviousInfobasePrefix);
		
		WriteLogEvent(EventLogMonitorMessageTextPereprefixionObjects(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

Function DataSelection(
					Val ObjectName,
					Val FromDate,
					Val ThisIsDocument,
					Val StandardPrefix,
					Val PreviousPrefix,
					Val ProcessAllData,
					Val ChooseOrganization = False)
	
	Query = New Query;
	
	If ProcessAllData Then
		
		If ThisIsDocument AND FromDate <> Undefined Then
			
			QueryText =
			"SELECT
			|	[SelectionCompanies]
			|	[CompanyPrefixSpecified]
			|	[DateSelection]
			|	Table.[Code] AS Code,
			|	Table.Ref AS Ref
			|FROM
			|	[ObjectName] AS Table
			|WHERE
			|	Table.Date >= &Date
			|
			|ORDER BY
			|	Table.Date";
			
			Query.SetParameter("Date", BegOfDay(FromDate));
			
		Else
			
			QueryText =
			"SELECT
			|	[SelectionCompanies]
			|	[CompanyPrefixSpecified]
			|	[DateSelection]
			|	Table.[Code] AS Code,
			|	Table.Ref AS Ref
			|FROM
			|	[ObjectName] AS Table";
			
		EndIf;
		
	Else
		
		If StandardPrefix Then
			
			If ThisIsDocument AND FromDate <> Undefined Then
				
				QueryText =
				"SELECT
				|	[SelectionCompanies]
				|	[CompanyPrefixSpecified]
				|	[DateSelection]
				|	Table.[Code] AS Code,
				|	Table.Ref AS Ref
				|FROM
				|	[ObjectName] AS Table
				|WHERE
				|	Table.Date >= &Date
				|	AND Table.[Code] LIKE &Prefix
				|
				|ORDER BY
				|	Table.Date";
				
				Query.SetParameter("Date", BegOfDay(FromDate));
				
			Else
				
				QueryText =
				"SELECT
				|	[SelectionCompanies]
				|	[CompanyPrefixSpecified]
				|	[DateSelection]
				|	Table.[Code] AS Code,
				|	Table.Ref AS Ref
				|FROM
				|	[ObjectName] AS Table
				|WHERE
				|	Table.[Code] LIKE &Prefix";
				
			EndIf;
			
			// Process objects created only in the current info base.
			Prefix = "%[Prefix]-%";
			Prefix = StrReplace(Prefix, "[Prefix]", PreviousPrefix);
			Query.SetParameter("Prefix", Prefix);
			
		Else
			
			If ThisIsDocument AND FromDate <> Undefined Then
				
				QueryText =
				"SELECT
				|	[SelectionCompanies]
				|	[CompanyPrefixSpecified]
				|	[DateSelection]
				|	Table.[Code] AS Code,
				|	Table.Ref AS Ref
				|FROM
				|	[ObjectName] AS Table
				|WHERE
				|	Table.Date >= &Date
				|
				|ORDER BY
				|	Table.Date";
				
				Query.SetParameter("Date", BegOfDay(FromDate));
				
			Else
				
				QueryText =
				"SELECT
				|	[SelectionCompanies]
				|	[CompanyPrefixSpecified]
				|	[DateSelection]
				|	Table.[Code] AS Code,
				|	Table.Ref AS Ref
				|FROM
				|	[ObjectName] AS Table";
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	QueryText = StrReplace(QueryText, "[ObjectName]", ObjectName);
	QueryText = StrReplace(QueryText, "[Code]", ?(ThisIsDocument, "Number", "Code"));
	If ChooseOrganization Then
		CompanyFieldName = ObjectPrefixationEvents.AttributeNameCompany(ObjectName);
	EndIf;
	QueryText = StrReplace(QueryText, "[SelectionCompanies]", 
		?(ChooseOrganization, "Table." + CompanyFieldName + " AS Company,", ""));
	QueryText = StrReplace(QueryText, "[CompanyPrefixSet]",
		?(ChooseOrganization,
		"CASE WHEN Table." + CompanyFieldName + ".Prefix = """" THEN False ELSE True END AS CompanyPrefixSpecified,",
		"False AS CompanyPrefixSet,"));
	QueryText = StrReplace(QueryText, "[DateSelection]", ?(ThisIsDocument, "Table.Date AS Date,", "Undefined AS Date,"));
	
	Query.Text = QueryText;
	
	Return Query.Execute();
EndFunction

Function ObjectNewCode(Val NewCodeFormat, Val Code, Val ThisIsDocument, Object)
	
	If TypeOf(Code) = Type("String") Then
		
		CodeByNumber = NumericalObjectCode(Code);
		
	ElsIf TypeOf(Code) = Type("Number") Then
		
		CodeByNumber = Code;
		
	EndIf;
	
	NewFullPrefix = FullPrefix(NewCodeFormat);
	
	CodeLength = StrLen(NewCodeFormat);
	
	CodeAsString = Format(CodeByNumber, "NZ=0; NG=0");
	
	LeadingZeroesCount = CodeLength - StrLen(NewFullPrefix) - StrLen(CodeAsString);
	
	If LeadingZeroesCount < 0 Then
		
		MessageString = NStr("en='Cannot convert %1 object %2.
		|Not long enough %1. Minimal length %1 of the object must be %3 symbols.';ru='Преобразование %1 объекта %2 не может быть выполнено.
		|Недостаточная длина %1. Минимальная длина %1 объекта должна составлять %3 символов.'");
		MessageString = StringFunctionsClientServer.PlaceParametersIntoString(MessageString,
					?(ThisIsDocument, NStr("en='Numbers';ru='номера'"), NStr("en='code';ru='кода'")),
					String(Object),
					String(StrLen(NewFullPrefix) + StrLen(CodeAsString)));
		Raise MessageString;
	EndIf;
	
	CodeLengthWithLeadingZeros = CodeLength - StrLen(NewFullPrefix);
	
	If CodeByNumber = 0 Then
		
		CodeWithLeadingZeros = Left("00000000000000000000000000000000000000000000000000", CodeLengthWithLeadingZeros);
		
	Else
		
		FormatString = "ND=%1; NLZ=; NG=0";
		FormatString = StringFunctionsClientServer.PlaceParametersIntoString(FormatString, String(CodeLengthWithLeadingZeros));
		CodeWithLeadingZeros = Format(CodeByNumber, FormatString);
		
	EndIf;
	
	Return NewFullPrefix + CodeWithLeadingZeros;
EndFunction

Function NewCodeBaseObjectCodeu(Val NewCodeFormat, Val BasicCode, Val ThisIsDocument, Object)
	
	NewFullPrefix = FullPrefix(NewCodeFormat);
	
	CodeLength = StrLen(NewCodeFormat);
	
	BasicCode = DeleteLeadingZeroes(BasicCode);
	
	LeadingZeroesCount = CodeLength - StrLen(NewFullPrefix) - StrLen(BasicCode);
	
	If LeadingZeroesCount < 0 Then
		
		MessageString = NStr("en='Cannot convert %1 object %2.
		|Not long enough %1. Minimal length %1 of the object must be %3 symbols.';ru='Преобразование %1 объекта %2 не может быть выполнено.
		|Недостаточная длина %1. Минимальная длина %1 объекта должна составлять %3 символов.'");
		MessageString = StringFunctionsClientServer.PlaceParametersIntoString(MessageString,
					?(ThisIsDocument, NStr("en='Numbers';ru='номера'"), NStr("en='code';ru='кода'")),
					String(Object),
					String(StrLen(NewFullPrefix) + StrLen(BasicCode)));
		Raise MessageString;
	EndIf;
	
	ZerosString = Left("00000000000000000000000000000000000000000000000000", LeadingZeroesCount);
	
	Return NewFullPrefix + ZerosString + BasicCode;
EndFunction

Function NumericalObjectCode(Val Code)
	
	Result = "";
	
	While StrLen(Code) > 0 Do
		
		Char = Right(Code, 1);
		
		If Find("0123456789", Char) > 0 Then
			Result = Char + Result;
		Else
			Break;
		EndIf;
		
		Code = Left(Code, StrLen(Code) - 1);
		
	EndDo;
	
	Return ?(IsBlankString(Result), 0, Number(Result));
EndFunction

Function FullPrefix(Val Code)
	
	While StrLen(Code) > 0 Do
		
		Char = Right(Code, 1);
		
		If Find("0123456789", Char) = 0 Then
			Break;
		EndIf;
		
		Code = Left(Code, StrLen(Code) - 1);
		
	EndDo;
	
	Return Code;
EndFunction

Function SubscriptionsOnEventsByHandlerName(Val HandlerName)
	
	Result = New Array;
	
	UpperHandlerName = Upper(HandlerName);
	
	For Each MetadataObject IN Metadata.EventSubscriptions Do
		
		If Upper(MetadataObject.Handler) = UpperHandlerName Then
			
			Result.Add(MetadataObject);
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

Function DeleteLeadingZeroes(Val Code)
	
	While StrLen(Code) > 0 Do
		
		If Left(Code, 1) <> "0" Then
			Break;
		EndIf;
		
		Code = Right(Code, StrLen(Code) - 1);
		
	EndDo;
	
	Return ?(IsBlankString(Code), "0", Code);
EndFunction

Procedure SupplementTableMetadata(Result, Val HandlerName)
	
	DataSeparationEnabled = CommonUseReUse.DataSeparationEnabled();
	
	For Each Subscription IN SubscriptionsOnEventsByHandlerName(HandlerName) Do
		
		For Each SourceType IN Subscription.Source.Types() Do
			
			SourceMetadata = Metadata.FindByType(SourceType);
			
			ObjectName = SourceMetadata.FullName();
			
			If Result.Find(ObjectName, "ObjectName") <> Undefined Then
				
				Continue;
				
			ElsIf DataSeparationEnabled Then
					
				If Not CommonUseReUse.IsSeparatedMetadataObject(ObjectName, CommonUseReUse.SupportDataSplitter())
					AND Not CommonUseReUse.IsSeparatedMetadataObject(ObjectName, CommonUseReUse.MainDataSeparator())Then
					
					Continue;
					
				EndIf;
				
			EndIf;
			
			Catalog             = False;
			ChartOfCharacteristicTypes = False;
			Document               = False;
			BusinessProcess          = False;
			Task                 = False;
			
			If CommonUse.ThisIsCatalog(SourceMetadata) Then
				
				Catalog = True;
				
			ElsIf CommonUse.ThisIsDocument(SourceMetadata) Then
				
				Document = True;
				
			ElsIf CommonUse.ThisIsChartOfCharacteristicTypes(SourceMetadata) Then
				
				ChartOfCharacteristicTypes = True;
				
			ElsIf CommonUse.ThisIsBusinessProcess(SourceMetadata) Then
				
				BusinessProcess = True;
				
			ElsIf CommonUse.ThisIsTask(SourceMetadata) Then
				
				Task = True;
				
			Else
				Continue;
			EndIf;
			
			ThisIsCatalog = Catalog OR ChartOfCharacteristicTypes;
			ThisIsDocument = Document OR BusinessProcess OR Task;
			
			ObjectDescription = Result.Add();
			ObjectDescription.Name = SourceMetadata.Name;
			ObjectDescription.ObjectName = ObjectName;
			
			ObjectDescription.Catalog             = Catalog;
			ObjectDescription.ChartOfCharacteristicTypes = ChartOfCharacteristicTypes;
			ObjectDescription.Document               = Document;
			ObjectDescription.BusinessProcess          = BusinessProcess;
			ObjectDescription.Task                 = Task;
			
			ObjectDescription.ThisIsCatalog = ThisIsCatalog;
			ObjectDescription.ThisIsDocument = ThisIsDocument;
			
			ObjectDescription.NumberPeriodicity = ObjectNumberPeriodicity(SourceMetadata, Document, BusinessProcess);
			
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure IncreaseProcessedObjectsCounter(ProcessedObjectsCounter)
	
	ProcessedObjectsCounter = ProcessedObjectsCounter + 1;
	
EndProcedure

Procedure SupplementStringWithZerosOnTheLeft(String, StringLength)
	
	String = StringFunctionsClientServer.SupplementString(String, StringLength, "0", "Left");
	
EndProcedure

//

Function MetadataUsedInfobasePrefix()
	
	Result = New ValueTable;
	Result.Columns.Add("Name");
	Result.Columns.Add("ObjectName");
	Result.Columns.Add("ThisIsCatalog");
	Result.Columns.Add("ThisIsDocument");
	Result.Columns.Add("Catalog");
	Result.Columns.Add("ChartOfCharacteristicTypes");
	Result.Columns.Add("Document");
	Result.Columns.Add("BusinessProcess");
	Result.Columns.Add("Task");
	Result.Columns.Add("NumberPeriodicity");
	
	SupplementTableMetadata(Result, "EventsObjectPrefixation.SetIBPrefix");
	SupplementTableMetadata(Result, "EventsObjectPrefixation.SetIBAndCompanyPrefix");
	
	Return Result;
EndFunction

Function MetadataUsingPrefixInformationBaseAndCompanies()
	
	Result = New ValueTable;
	Result.Columns.Add("Name");
	Result.Columns.Add("ObjectName");
	Result.Columns.Add("ThisIsCatalog");
	Result.Columns.Add("ThisIsDocument");
	Result.Columns.Add("Catalog");
	Result.Columns.Add("ChartOfCharacteristicTypes");
	Result.Columns.Add("Document");
	Result.Columns.Add("BusinessProcess");
	Result.Columns.Add("Task");
	Result.Columns.Add("NumberPeriodicity");
	
	SupplementTableMetadata(Result, "EventsObjectPrefixation.SetIBAndCompanyPrefix");
	
	Return Result;
EndFunction

Function MetadataUsingOnlyPrefixInformationBase()
	
	Result = New ValueTable;
	Result.Columns.Add("Name");
	Result.Columns.Add("ObjectName");
	Result.Columns.Add("ThisIsCatalog");
	Result.Columns.Add("ThisIsDocument");
	Result.Columns.Add("Catalog");
	Result.Columns.Add("ChartOfCharacteristicTypes");
	Result.Columns.Add("Document");
	Result.Columns.Add("BusinessProcess");
	Result.Columns.Add("Task");
	Result.Columns.Add("NumberPeriodicity");
	
	SupplementTableMetadata(Result, "EventsObjectPrefixation.SetIBPrefix");
	
	Return Result;
EndFunction

Function CreateObject(ObjectDescription)
	
	If ObjectDescription.Catalog Then
		
		Return Catalogs[ObjectDescription.Name].CreateItem();
		
	ElsIf ObjectDescription.Document Then
		
		Return Documents[ObjectDescription.Name].CreateDocument();
		
	ElsIf ObjectDescription.ChartOfCharacteristicTypes Then
		
		Return ChartsOfCharacteristicTypes[ObjectDescription.Name].CreateItem();
		
	ElsIf ObjectDescription.BusinessProcess Then
		
		Return BusinessProcesses[ObjectDescription.Name].CreateBusinessProcess();
		
	ElsIf ObjectDescription.Task Then
		
		Return Tasks[ObjectDescription.Name].CreateTask();
		
	EndIf;
	
	Return Undefined;
EndFunction

Function ObjectNumberPeriodicity(Object, Val Document, Val BusinessProcess)
	
	Result = Metadata.ObjectProperties.DocumentNumberPeriodicity.Nonperiodical;
	
	If Document Then
		
		Result = Object.NumberPeriodicity;
		
	ElsIf BusinessProcess Then
		
		If Object.NumberPeriodicity = Metadata.ObjectProperties.BusinessProcessNumberPeriodicity.Year Then
			
			Result = Metadata.ObjectProperties.DocumentNumberPeriodicity.Year;
			
		ElsIf Object.NumberPeriodicity = Metadata.ObjectProperties.BusinessProcessNumberPeriodicity.Day Then
			
			Result = Metadata.ObjectProperties.DocumentNumberPeriodicity.Day;
			
		ElsIf Object.NumberPeriodicity = Metadata.ObjectProperties.BusinessProcessNumberPeriodicity.Quarter Then
			
			Result = Metadata.ObjectProperties.DocumentNumberPeriodicity.Quarter;
			
		ElsIf Object.NumberPeriodicity = Metadata.ObjectProperties.BusinessProcessNumberPeriodicity.Month Then
			
			Result = Metadata.ObjectProperties.DocumentNumberPeriodicity.Month;
			
		ElsIf Object.NumberPeriodicity = Metadata.ObjectProperties.BusinessProcessNumberPeriodicity.Nonperiodical Then
			
			Result = Metadata.ObjectProperties.DocumentNumberPeriodicity.Nonperiodical;
			
		EndIf;
		
	EndIf;
	
	Return Result;
EndFunction

Function PeriodDate(Val Date, Val Periodicity)
	
	If Periodicity = Metadata.ObjectProperties.DocumentNumberPeriodicity.Year Then
		
		Return BegOfYear(Date);
		
	ElsIf Periodicity = Metadata.ObjectProperties.DocumentNumberPeriodicity.Quarter Then
		
		Return BegOfQuarter(Date);
		
	ElsIf Periodicity = Metadata.ObjectProperties.DocumentNumberPeriodicity.Month Then
		
		Return BegOfMonth(Date);
		
	ElsIf Periodicity = Metadata.ObjectProperties.DocumentNumberPeriodicity.Day Then
		
		Return BegOfDay(Date);
		
	ElsIf Periodicity = Metadata.ObjectProperties.DocumentNumberPeriodicity.Nonperiodical Then
		
		Return Date('00010101');
		
	EndIf;
	
	Return Date('00010101');
EndFunction

Procedure SetNewPrefix(
						Val PrefixLength,
						Val ObjectDescription,
						Val FromDate,
						Val PreviousInfobasePrefix,
						Val ProcessAllData,
						Val NewPrefixComplete,
						ProcessedObjectsCounter)
	
	Selection = DataSelection(
			ObjectDescription.ObjectName,
			FromDate,
			ObjectDescription.ThisIsDocument,
			True,
			PreviousInfobasePrefix,
			ProcessAllData);
	
	If Selection.IsEmpty() Then
		Return;
	EndIf;
	
	Selection = Selection.Select();
	
	While Selection.Next() Do
		
		If PrefixLength = 2 Then
			
			If Mid(Selection.Code, 3, 1) <> "-" Then
				Continue; // Custom code format
			EndIf;
			
			CodeNew = NewPrefixComplete + Mid(Selection.Code, 3);
			
		Else // PrefixLength = 4
			
			If Mid(Selection.Code, 5, 1) <> "-" Then
				Continue; // Custom code format
			EndIf;
			
			CodeNew = Left(Selection.Code, 2) + NewPrefixComplete + Mid(Selection.Code, 5);
			
		EndIf;
		
		ObjectModified = (Selection.Code <> CodeNew);
		
		If ObjectModified Then
			
			Object = Selection.Ref.GetObject();
			
			Object[?(ObjectDescription.ThisIsDocument, "Number", "Code")] = CodeNew;
			
			Object.DataExchange.Load = True;
			Object.Write();
			
			IncreaseProcessedObjectsCounter(ProcessedObjectsCounter);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure CheckPrefixSetPossibility()
	
	FunctionalOptionInUse = Undefined;
	OnDeterminingFunctionalBasePrefixInformationOptions(FunctionalOptionInUse);
	If Not FunctionalOptionInUse Then
		
		Raise NStr("en='Objects prefixation is unavailable.';ru='Перепрефиксация объектов недоступна.'");
		
	EndIf;
	
EndProcedure

Function EventLogMonitorMessageTextPereprefixionObjects()
	
	Return NStr("en='Objects prefixation. Infobase prefix modification';ru='Префиксация объектов.Изменение префикса информационной базы'", CommonUseClientServer.MainLanguageCode());
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Handlers of the conditional calls into other subsystems.

// Returns a flag showing that functional option CompanyPrefixes exists in the configuration.
//
// Parameters:
//  FunctionalOptionInUse - Boolean - flag showing that functional option CompanyPrefixes exists in the configuration.
//
Procedure WhenDeterminingFunctionalOptionsOfCompanyPrefixes(FunctionalOptionInUse) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.Companies") Then
		FunctionalOptionInUse = True;
	Else
		FunctionalOptionInUse = False;
	EndIf;
	
EndProcedure

// Returns a flag showing that functional option InfobasePrefix exists in the configuration.
//
// Parameters:
//  FunctionalOptionInUse - Boolean - flag showing that functional
//                                    option InfobasePrefix exists in the configuration.
//
Procedure OnDeterminingFunctionalBasePrefixInformationOptions(FunctionalOptionInUse) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.DataExchange") Then
		FunctionalOptionInUse = True;
	Else
		FunctionalOptionInUse = False;
	EndIf;
	
EndProcedure

// Returns prefix of this infobase.
//
Procedure WhenDeterminingPrefixInformationBase(InfobasePrefix) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = CommonUse.CommonModule("DataExchangeServer");
		InfobasePrefix = ModuleDataExchangeServer.InfobasePrefix();
	Else
		InfobasePrefix = "";
	EndIf;
	
EndProcedure

// Returns a company prefix.
//
// Parameters:
//  Company - CatalogRef.Companies - company for which it is required to get a prefix.
//  CompanyPrefix - String - company prefix.
//
Procedure WhenPrefixDefinitionOrganization(Val Company, CompanyPrefix) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.Companies") Then
		FunctionalOptionName = "CompanyPrefixes";
		CompanyPrefix = GetFunctionalOption(FunctionalOptionName, New Structure("Company", Company));
	Else
		CompanyPrefix = "";
	EndIf;
	
EndProcedure

// Sets prefix for this infobase.
//
Procedure SetIBPrefix(Val Prefix) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = CommonUse.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.SetIBPrefix(Prefix);
	EndIf;
	
EndProcedure

#EndRegion
