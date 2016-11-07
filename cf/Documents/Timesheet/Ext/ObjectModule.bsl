#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	ExceptionArray = New Array;
	ExceptionArray.Add(Catalogs.WorkingHoursKinds.WeekEnd);
	ExceptionArray.Add(Catalogs.WorkingHoursKinds.MainVacation);
	
	If DataInputMethod = Enums.TimeDataInputMethods.ByDays Then
		
		For Each TSRow IN WorkedTimeByDays Do
			
			For Counter = 1 To 31 Do
			
				If ValueIsFilled(TSRow["FirstTimeKind" + Counter])
					AND Not ValueIsFilled(TSRow["FirstHours" + Counter]) Then
					
					If ExceptionArray.Find(TSRow["FirstTimeKind" + Counter]) = Undefined Then 
					
						SmallBusinessServer.ShowMessageAboutError(ThisObject, 
						"Hour quantity by time kind isn't specified.",
						"WorkedTimeByDays",
						TSRow.LineNumber,
						"FirstHours" + Counter,
						Cancel);
						
					EndIf;
					
				EndIf;
				
				If ValueIsFilled(TSRow["SecondTimeKind" + Counter])
					AND Not ValueIsFilled(TSRow["SecondHours" + Counter]) Then
					
					If ExceptionArray.Find(TSRow["SecondTimeKind" + Counter]) = Undefined Then 
					
						SmallBusinessServer.ShowMessageAboutError(ThisObject, 
						"Hour quantity by time kind isn't specified.",
						"WorkedTimeByDays",
						TSRow.LineNumber,
						"SecondHours" + Counter,
						Cancel);
						
					EndIf;
					
				EndIf;
				
				If ValueIsFilled(TSRow["ThirdTimeKind" + Counter])
					AND Not ValueIsFilled(TSRow["ThirdHours" + Counter]) Then
					
					If ExceptionArray.Find(TSRow["ThirdTimeKind" + Counter]) = Undefined Then 
					
						SmallBusinessServer.ShowMessageAboutError(ThisObject, 
						"Hour quantity by time kind isn't specified.",
						"WorkedTimeByDays",
						TSRow.LineNumber,
						"ThirdHours" + Counter,
						Cancel);
						
					EndIf;
					
				EndIf;
			
			EndDo;		
			
		EndDo; 
		
	Else	
		
		For Each TSRow IN WorkedTimePerPeriod Do
			For Counter = 1 To 6 Do
			
				If ValueIsFilled(TSRow["TimeKind" + Counter])
					AND Not ValueIsFilled(TSRow["Days" + Counter])
					AND Not ValueIsFilled(TSRow["Hours" + Counter]) Then
					SmallBusinessServer.ShowMessageAboutError(ThisObject, 
					"Day and hour quantity by time kind isn't specified.",
					"WorkedTimePerPeriod",
					TSRow.LineNumber,
					"TimeKind" + Counter,
					Cancel);
				EndIf;
			
			EndDo;		
		EndDo;
		
	EndIf;
	
EndProcedure // FillCheckProcessing()

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.Timesheet.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	SmallBusinessServer.ReflectTimesheet(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure // Posting()

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties to undo document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	SmallBusinessServer.WriteRecordSets(ThisObject);
		
EndProcedure

#EndRegion

#EndIf