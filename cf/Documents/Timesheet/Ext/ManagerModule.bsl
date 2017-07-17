#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentTimesheet, StructureAdditionalProperties) Export

	If DocumentTimesheet.DataInputMethod = Enums.TimeDataInputMethods.TotalForPeriod Then
	
		QueryText = "";
		For Counter = 1 To 6 Do
		
			QueryText = 	QueryText + ?(Counter > 1, "	
			|UNION ALL
			| 
			|", "") + 
			"SELECT
			|	&Company AS Company,
			|	TimesheetWorkedTimePerPeriod.Ref.RegistrationPeriod 	AS Period,
			|	TRUE									 					AS TotalForPeriod,
			|	TimesheetWorkedTimePerPeriod.Employee 					AS Employee,
			|	TimesheetWorkedTimePerPeriod.Ref.StructuralUnit 	AS StructuralUnit,
			|	TimesheetWorkedTimePerPeriod.Position 					AS Position,
			|	TimesheetWorkedTimePerPeriod.TimeKind" + Counter + " 	AS TimeKind,
			|	TimesheetWorkedTimePerPeriod.Days" + Counter + " 		AS Days,
			|	TimesheetWorkedTimePerPeriod.Hours" + Counter + " 		AS Hours
			|FROM
			|	Document.Timesheet.WorkedTimePerPeriod AS TimesheetWorkedTimePerPeriod
			|WHERE
			|	TimesheetWorkedTimePerPeriod.TimeKind" + Counter + " <> VALUE(Catalog.WorkingHoursKinds.EmptyRef) And TimesheetWorkedTimePerPeriod.Ref = &Ref
			|	";
		
		EndDo; 
		
	Else        
		
		QueryText = "";
		For Counter = 1 To 31 Do
		
			QueryText = QueryText + ?(Counter > 1, "	
			|UNION ALL
			| 
			|", "") + 
			"SELECT
			|	&Company 															AS Company,
			|	FALSE									 								AS TotalForPeriod,
			|	TimesheetWorkedTimeByDays.Employee 								AS Employee,
			|	TimesheetWorkedTimeByDays.Ref.StructuralUnit 				AS StructuralUnit,
			|	TimesheetWorkedTimeByDays.Position 								AS Position,
			|	DATEADD(TimesheetWorkedTimeByDays.Ref.RegistrationPeriod, Day, " + (Counter - 1) + ") AS Period, 
			|	1 AS Days, 
			|	TimesheetWorkedTimeByDays.FirstTimeKind" + Counter + " 			AS TimeKind, 
			|	TimesheetWorkedTimeByDays.FirstHours" + Counter + " 				AS Hours
			|FROM
			|	Document.Timesheet.WorkedTimeByDays AS TimesheetWorkedTimeByDays
			|WHERE
			|	TimesheetWorkedTimeByDays.Ref = &Ref
			|	AND TimesheetWorkedTimeByDays.FirstTimeKind" + Counter + " <> VALUE(Catalog.WorkingHoursKinds.EmptyRef)
			|		
			|UNION ALL
			|
			|SELECT
			|	&Company,
			|	FALSE,
			|	TimesheetWorkedTimeByDays.Employee,
			|	TimesheetWorkedTimeByDays.Ref.StructuralUnit,
			|	TimesheetWorkedTimeByDays.Position,
			|	DATEADD(TimesheetWorkedTimeByDays.Ref.RegistrationPeriod, Day, " + (Counter - 1) + "), 
|	1, 
|	TimesheetWorkedTimeByDays.SecondTimeKind" + Counter + ",
			|	TimesheetWorkedTimeByDays.SecondHours" + Counter + "
			|FROM
			|	Document.Timesheet.WorkedTimeByDays AS
			|TimesheetWorkedTimeByDays
			|	WHERE TimesheetWorkedTimeByDays.Ref =
			|	&Ref AND TimesheetWorkedTimeByDays.SecondTimeKind" + Counter + " <> VALUE(Catalog.WorkingHoursKinds.EmptyRef)
			|		
			|UNION ALL
			|
			|SELECT
			|	&Company,
			|	FALSE,
			|	TimesheetWorkedTimeByDays.Employee,
			|	TimesheetWorkedTimeByDays.Ref.StructuralUnit,
			|	TimesheetWorkedTimeByDays.Position,
			|	DATEADD(TimesheetWorkedTimeByDays.Ref.RegistrationPeriod, Day, " + (Counter - 1) + "),
|	 1, 
|	TimesheetWorkedTimeByDays.ThirdTimeKind" + Counter + ",
			|	TimesheetWorkedTimeByDays.ThirdHours" + Counter + "
			|FROM
			|	Document.Timesheet.WorkedTimeByDays
			|AS
			|	TimesheetWorkedTimeByDays WHERE TimesheetWorkedTimeByDays.Ref
			|	= &Ref AND TimesheetWorkedTimeByDays.ThirdTimeKind" + Counter + " <> VALUE(Catalog.WorkingHoursKinds.EmptyRef)
			|";	
		
		EndDo;
		
	EndIf; 
		
	Query = New Query(QueryText);
	
	Query.SetParameter("Ref", DocumentTimesheet);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("ScheduleTable", Query.Execute().Unload());
	
EndProcedure // DocumentDataInitialization()

// Function checks whether data should be added to the worked time
Function AddToWorkedTime(TimeKind)
	
	If TimeKind = Catalogs.WorkingHoursKinds.Holidays
		OR TimeKind = Catalogs.WorkingHoursKinds.Overtime
		OR TimeKind = Catalogs.WorkingHoursKinds.Work Then
	
		Return True;	
	Else	
		Return False;	
	EndIf; 
	
EndFunction

#EndRegion

#Region PrintInterface

Function PrintForm(ObjectsArray, PrintObjects)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_Timesheet";
	
	FirstDocument = True;
	
	For Each CurrentDocument IN ObjectsArray Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		Query = New Query();
		Query.SetParameter("CurrentDocument", CurrentDocument);
		Query.Text = 
		"SELECT
		|	Timesheet.Date AS DocumentDate,
		|	Timesheet.StructuralUnit AS StructuralUnit,
		|	Timesheet.RegistrationPeriod AS RegistrationPeriod,
		|	Timesheet.Number,
		|	Timesheet.Company.Prefix AS Prefix,
		|	Timesheet.Company.DescriptionFull,
		|	Timesheet.Company,
		|	Timesheet.DataInputMethod
		|FROM
		|	Document.Timesheet AS Timesheet
		|WHERE
		|	Timesheet.Ref = &CurrentDocument";
		
		Header = Query.Execute().Select();
		Header.Next();
		
		If Header.DataInputMethod = Enums.TimeDataInputMethods.ByDays Then
			SpreadsheetDocument.PrintParametersKey = "PARAMETERS_PRINT_Timesheet_Template";		
			Template = PrintManagement.PrintedFormsTemplate("Document.Timesheet.PF_MXL_Template");
		Else
			SpreadsheetDocument.PrintParametersKey = "PRINTING_PARAMETERS_Timesheet_TemplateFree";		
			Template = PrintManagement.PrintedFormsTemplate("Document.Timesheet.PF_MXL_TemplateComposite");
		EndIf;
		
		AreaDocumentHeader = Template.GetArea("DocumentHeader");
		AreaHeader          = Template.GetArea("Header");
		AreaDetails         = Template.GetArea("Details");
		FooterArea         = Template.GetArea("Footer");
		
		If Header.DocumentDate < Date('20110101') Then
			DocumentNumber = SmallBusinessServer.GetNumberForPrinting(Header.Number, Header.Prefix);
		Else
			DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
		EndIf;		
		
		AreaDocumentHeader.Parameters.NameOfOrganization = Header.CompanyDescriptionFull;
		AreaDocumentHeader.Parameters.NameDeparnments = Header.StructuralUnit;
		AreaDocumentHeader.Parameters.DocumentNumber = DocumentNumber;
		AreaDocumentHeader.Parameters.DateOfFilling = Header.DocumentDate;
		AreaDocumentHeader.Parameters.DateBeg = Header.RegistrationPeriod;
		AreaDocumentHeader.Parameters.DateEnd = EndOfMonth(Header.RegistrationPeriod);
				
		SpreadsheetDocument.Put(AreaDocumentHeader);
		SpreadsheetDocument.Put(AreaHeader);
		                                             
		Query = New Query;
		Query.SetParameter("Ref",   CurrentDocument);
		Query.SetParameter("RegistrationPeriod",   Header.RegistrationPeriod);
		
		If Header.DataInputMethod = Enums.TimeDataInputMethods.ByDays Then
				
			Query.Text =
			"SELECT
			|	IndividualsDescriptionFullSliceLast.Surname,
			|	IndividualsDescriptionFullSliceLast.Name,
			|	IndividualsDescriptionFullSliceLast.Patronymic,
			|	TimesheetWorkedTimeByDays.Employee,
			|	TimesheetWorkedTimeByDays.Position,
			|	TimesheetWorkedTimeByDays.FirstTimeKind1,
			|	TimesheetWorkedTimeByDays.FirstTimeKind2,
			|	TimesheetWorkedTimeByDays.FirstTimeKind3,
			|	TimesheetWorkedTimeByDays.FirstTimeKind4,
			|	TimesheetWorkedTimeByDays.FirstTimeKind5,
			|	TimesheetWorkedTimeByDays.FirstTimeKind6,
			|	TimesheetWorkedTimeByDays.FirstTimeKind7,
			|	TimesheetWorkedTimeByDays.FirstTimeKind8,
			|	TimesheetWorkedTimeByDays.FirstTimeKind9,
			|	TimesheetWorkedTimeByDays.FirstTimeKind10,
			|	TimesheetWorkedTimeByDays.FirstTimeKind11,
			|	TimesheetWorkedTimeByDays.FirstTimeKind12,
			|	TimesheetWorkedTimeByDays.FirstTimeKind13,
			|	TimesheetWorkedTimeByDays.FirstTimeKind14,
			|	TimesheetWorkedTimeByDays.FirstTimeKind15,
			|	TimesheetWorkedTimeByDays.FirstTimeKind16,
			|	TimesheetWorkedTimeByDays.FirstTimeKind17,
			|	TimesheetWorkedTimeByDays.FirstTimeKind18,
			|	TimesheetWorkedTimeByDays.FirstTimeKind19,
			|	TimesheetWorkedTimeByDays.FirstTimeKind20,
			|	TimesheetWorkedTimeByDays.FirstTimeKind21,
			|	TimesheetWorkedTimeByDays.FirstTimeKind22,
			|	TimesheetWorkedTimeByDays.FirstTimeKind23,
			|	TimesheetWorkedTimeByDays.FirstTimeKind24,
			|	TimesheetWorkedTimeByDays.FirstTimeKind25,
			|	TimesheetWorkedTimeByDays.FirstTimeKind26,
			|	TimesheetWorkedTimeByDays.FirstTimeKind27,
			|	TimesheetWorkedTimeByDays.FirstTimeKind28,
			|	TimesheetWorkedTimeByDays.FirstTimeKind29,
			|	TimesheetWorkedTimeByDays.FirstTimeKind30,
			|	TimesheetWorkedTimeByDays.FirstTimeKind31,
			|	TimesheetWorkedTimeByDays.SecondTimeKind1,
			|	TimesheetWorkedTimeByDays.SecondTimeKind2,
			|	TimesheetWorkedTimeByDays.SecondTimeKind3,
			|	TimesheetWorkedTimeByDays.SecondTimeKind4,
			|	TimesheetWorkedTimeByDays.SecondTimeKind5,
			|	TimesheetWorkedTimeByDays.SecondTimeKind6,
			|	TimesheetWorkedTimeByDays.SecondTimeKind7,
			|	TimesheetWorkedTimeByDays.SecondTimeKind8,
			|	TimesheetWorkedTimeByDays.SecondTimeKind9,
			|	TimesheetWorkedTimeByDays.SecondTimeKind10,
			|	TimesheetWorkedTimeByDays.SecondTimeKind11,
			|	TimesheetWorkedTimeByDays.SecondTimeKind12,
			|	TimesheetWorkedTimeByDays.SecondTimeKind13,
			|	TimesheetWorkedTimeByDays.SecondTimeKind14,
			|	TimesheetWorkedTimeByDays.SecondTimeKind15,
			|	TimesheetWorkedTimeByDays.SecondTimeKind16,
			|	TimesheetWorkedTimeByDays.SecondTimeKind17,
			|	TimesheetWorkedTimeByDays.SecondTimeKind18,
			|	TimesheetWorkedTimeByDays.SecondTimeKind19,
			|	TimesheetWorkedTimeByDays.SecondTimeKind20,
			|	TimesheetWorkedTimeByDays.SecondTimeKind21,
			|	TimesheetWorkedTimeByDays.SecondTimeKind22,
			|	TimesheetWorkedTimeByDays.SecondTimeKind23,
			|	TimesheetWorkedTimeByDays.SecondTimeKind24,
			|	TimesheetWorkedTimeByDays.SecondTimeKind25,
			|	TimesheetWorkedTimeByDays.SecondTimeKind26,
			|	TimesheetWorkedTimeByDays.SecondTimeKind27,
			|	TimesheetWorkedTimeByDays.SecondTimeKind28,
			|	TimesheetWorkedTimeByDays.SecondTimeKind29,
			|	TimesheetWorkedTimeByDays.SecondTimeKind30,
			|	TimesheetWorkedTimeByDays.SecondTimeKind31,
			|	TimesheetWorkedTimeByDays.ThirdTimeKind1,
			|	TimesheetWorkedTimeByDays.ThirdTimeKind2,
			|	TimesheetWorkedTimeByDays.ThirdTimeKind3,
			|	TimesheetWorkedTimeByDays.ThirdTimeKind4,
			|	TimesheetWorkedTimeByDays.ThirdTimeKind5,
			|	TimesheetWorkedTimeByDays.ThirdTimeKind6,
			|	TimesheetWorkedTimeByDays.ThirdTimeKind7,
			|	TimesheetWorkedTimeByDays.ThirdTimeKind8,
			|	TimesheetWorkedTimeByDays.ThirdTimeKind9,
			|	TimesheetWorkedTimeByDays.ThirdTimeKind10,
			|	TimesheetWorkedTimeByDays.ThirdTimeKind11,
			|	TimesheetWorkedTimeByDays.ThirdTimeKind12,
			|	TimesheetWorkedTimeByDays.ThirdTimeKind13,
			|	TimesheetWorkedTimeByDays.ThirdTimeKind14,
			|	TimesheetWorkedTimeByDays.ThirdTimeKind15,
			|	TimesheetWorkedTimeByDays.ThirdTimeKind16,
			|	TimesheetWorkedTimeByDays.ThirdTimeKind17,
			|	TimesheetWorkedTimeByDays.ThirdTimeKind18,
			|	TimesheetWorkedTimeByDays.ThirdTimeKind19,
			|	TimesheetWorkedTimeByDays.ThirdTimeKind20,
			|	TimesheetWorkedTimeByDays.ThirdTimeKind21,
			|	TimesheetWorkedTimeByDays.ThirdTimeKind22,
			|	TimesheetWorkedTimeByDays.ThirdTimeKind23,
			|	TimesheetWorkedTimeByDays.ThirdTimeKind24,
			|	TimesheetWorkedTimeByDays.ThirdTimeKind25,
			|	TimesheetWorkedTimeByDays.ThirdTimeKind26,
			|	TimesheetWorkedTimeByDays.ThirdTimeKind27,
			|	TimesheetWorkedTimeByDays.ThirdTimeKind28,
			|	TimesheetWorkedTimeByDays.ThirdTimeKind29,
			|	TimesheetWorkedTimeByDays.ThirdTimeKind30,
			|	TimesheetWorkedTimeByDays.ThirdTimeKind31,
			|	TimesheetWorkedTimeByDays.FirstHours1,
			|	TimesheetWorkedTimeByDays.FirstHours2,
			|	TimesheetWorkedTimeByDays.FirstHours3,
			|	TimesheetWorkedTimeByDays.FirstHours4,
			|	TimesheetWorkedTimeByDays.FirstHours5,
			|	TimesheetWorkedTimeByDays.FirstHours6,
			|	TimesheetWorkedTimeByDays.FirstHours7,
			|	TimesheetWorkedTimeByDays.FirstHours8,
			|	TimesheetWorkedTimeByDays.FirstHours9,
			|	TimesheetWorkedTimeByDays.FirstHours10,
			|	TimesheetWorkedTimeByDays.FirstHours11,
			|	TimesheetWorkedTimeByDays.FirstHours12,
			|	TimesheetWorkedTimeByDays.FirstHours13,
			|	TimesheetWorkedTimeByDays.FirstHours14,
			|	TimesheetWorkedTimeByDays.FirstHours15,
			|	TimesheetWorkedTimeByDays.FirstHours16,
			|	TimesheetWorkedTimeByDays.FirstHours17,
			|	TimesheetWorkedTimeByDays.FirstHours18,
			|	TimesheetWorkedTimeByDays.FirstHours19,
			|	TimesheetWorkedTimeByDays.FirstHours20,
			|	TimesheetWorkedTimeByDays.FirstHours21,
			|	TimesheetWorkedTimeByDays.FirstHours22,
			|	TimesheetWorkedTimeByDays.FirstHours23,
			|	TimesheetWorkedTimeByDays.FirstHours24,
			|	TimesheetWorkedTimeByDays.FirstHours25,
			|	TimesheetWorkedTimeByDays.FirstHours26,
			|	TimesheetWorkedTimeByDays.FirstHours27,
			|	TimesheetWorkedTimeByDays.FirstHours28,
			|	TimesheetWorkedTimeByDays.FirstHours29,
			|	TimesheetWorkedTimeByDays.FirstHours30,
			|	TimesheetWorkedTimeByDays.FirstHours31,
			|	TimesheetWorkedTimeByDays.SecondHours1,
			|	TimesheetWorkedTimeByDays.SecondHours2,
			|	TimesheetWorkedTimeByDays.SecondHours3,
			|	TimesheetWorkedTimeByDays.SecondHours4,
			|	TimesheetWorkedTimeByDays.SecondHours5,
			|	TimesheetWorkedTimeByDays.SecondHours6,
			|	TimesheetWorkedTimeByDays.SecondHours7,
			|	TimesheetWorkedTimeByDays.SecondHours8,
			|	TimesheetWorkedTimeByDays.SecondHours9,
			|	TimesheetWorkedTimeByDays.SecondHours10,
			|	TimesheetWorkedTimeByDays.SecondHours11,
			|	TimesheetWorkedTimeByDays.SecondHours12,
			|	TimesheetWorkedTimeByDays.SecondHours13,
			|	TimesheetWorkedTimeByDays.SecondHours14,
			|	TimesheetWorkedTimeByDays.SecondHours15,
			|	TimesheetWorkedTimeByDays.SecondHours16,
			|	TimesheetWorkedTimeByDays.SecondHours17,
			|	TimesheetWorkedTimeByDays.SecondHours18,
			|	TimesheetWorkedTimeByDays.SecondHours19,
			|	TimesheetWorkedTimeByDays.SecondHours20,
			|	TimesheetWorkedTimeByDays.SecondHours21,
			|	TimesheetWorkedTimeByDays.SecondHours22,
			|	TimesheetWorkedTimeByDays.SecondHours23,
			|	TimesheetWorkedTimeByDays.SecondHours24,
			|	TimesheetWorkedTimeByDays.SecondHours25,
			|	TimesheetWorkedTimeByDays.SecondHours26,
			|	TimesheetWorkedTimeByDays.SecondHours27,
			|	TimesheetWorkedTimeByDays.SecondHours28,
			|	TimesheetWorkedTimeByDays.SecondHours29,
			|	TimesheetWorkedTimeByDays.SecondHours30,
			|	TimesheetWorkedTimeByDays.SecondHours31,
			|	TimesheetWorkedTimeByDays.ThirdHours1,
			|	TimesheetWorkedTimeByDays.ThirdHours2,
			|	TimesheetWorkedTimeByDays.ThirdHours3,
			|	TimesheetWorkedTimeByDays.ThirdHours4,
			|	TimesheetWorkedTimeByDays.ThirdHours5,
			|	TimesheetWorkedTimeByDays.ThirdHours6,
			|	TimesheetWorkedTimeByDays.ThirdHours7,
			|	TimesheetWorkedTimeByDays.ThirdHours8,
			|	TimesheetWorkedTimeByDays.ThirdHours9,
			|	TimesheetWorkedTimeByDays.ThirdHours10,
			|	TimesheetWorkedTimeByDays.ThirdHours11,
			|	TimesheetWorkedTimeByDays.ThirdHours12,
			|	TimesheetWorkedTimeByDays.ThirdHours13,
			|	TimesheetWorkedTimeByDays.ThirdHours14,
			|	TimesheetWorkedTimeByDays.ThirdHours15,
			|	TimesheetWorkedTimeByDays.ThirdHours16,
			|	TimesheetWorkedTimeByDays.ThirdHours17,
			|	TimesheetWorkedTimeByDays.ThirdHours18,
			|	TimesheetWorkedTimeByDays.ThirdHours19,
			|	TimesheetWorkedTimeByDays.ThirdHours20,
			|	TimesheetWorkedTimeByDays.ThirdHours21,
			|	TimesheetWorkedTimeByDays.ThirdHours22,
			|	TimesheetWorkedTimeByDays.ThirdHours23,
			|	TimesheetWorkedTimeByDays.ThirdHours24,
			|	TimesheetWorkedTimeByDays.ThirdHours25,
			|	TimesheetWorkedTimeByDays.ThirdHours26,
			|	TimesheetWorkedTimeByDays.ThirdHours27,
			|	TimesheetWorkedTimeByDays.ThirdHours28,
			|	TimesheetWorkedTimeByDays.ThirdHours29,
			|	TimesheetWorkedTimeByDays.ThirdHours30,
			|	TimesheetWorkedTimeByDays.ThirdHours31,
			|	TimesheetWorkedTimeByDays.Employee.Code AS TabNumber
			|FROM
			|	Document.Timesheet.WorkedTimeByDays AS TimesheetWorkedTimeByDays
			|		LEFT JOIN InformationRegister.IndividualsDescriptionFull.SliceLast(&RegistrationPeriod, ) AS IndividualsDescriptionFullSliceLast
			|		ON TimesheetWorkedTimeByDays.Employee.Ind = IndividualsDescriptionFullSliceLast.Ind
			|WHERE
			|	TimesheetWorkedTimeByDays.Ref = &Ref
			|
			|ORDER BY
			|	TimesheetWorkedTimeByDays.LineNumber";
			
			Selection = Query.Execute().Select();
            				
			NPP = 0;
			While Selection.Next() Do
				FirstHalfHour = 0;
				DaysOfFirstHalf = 0;
				HoursSecondHalf = 0;
				DaysSecondHalf = 0;
				NPP = NPP + 1;				
				AreaDetails.Parameters.SerialNumber = NPP;
				AreaDetails.Parameters.Fill(Selection);
				If ValueIsFilled(Selection.Surname) Then
					Initials = SmallBusinessServer.GetSurnameNamePatronymic(Selection.Surname, Selection.Name, Selection.Patronymic, True);
				Else
					Initials = "";
				EndIf;
				AreaDetails.Parameters.DescriptionEmployee = ?(ValueIsFilled(Initials), Initials, Selection.Employee);
				
				For Counter = 1 To 15 Do
					
				    RowTypeOfTime = "" + Selection["FirstTimeKind" + Counter] + ?(ValueIsFilled(Selection["SecondTimeKind" + Counter]), "/" + Selection["SecondTimeKind" + Counter], "") + ?(ValueIsFilled(Selection["ThirdTimeKind" + Counter]), "/" + Selection["ThirdTimeKind" + Counter], "");
					StringHours = "" + ?(Selection["FirstHours" + Counter] = 0, "", Selection["FirstHours" + Counter]) + ?(ValueIsFilled(Selection["SecondTimeKind" + Counter]), "/" + Selection["SecondHours" + Counter], "") + ?(ValueIsFilled(Selection["ThirdTimeKind" + Counter]), "/" + Selection["ThirdHours" + Counter], "");
								 
					AreaDetails.Parameters["Char" + Counter] = RowTypeOfTime;			 
					AreaDetails.Parameters["AdditionalValue" + Counter] = StringHours;			 
								 
					Hours = ?(AddToWorkedTime(Selection["FirstTimeKind" + Counter]), Selection["FirstHours" + Counter], 0) 
							+ ?(AddToWorkedTime(Selection["SecondTimeKind" + Counter]), Selection["SecondHours" + Counter], 0) 
							+ ?(AddToWorkedTime(Selection["ThirdTimeKind" + Counter]), Selection["ThirdHours" + Counter], 0);
					FirstHalfHour = FirstHalfHour +  Hours;
					DaysOfFirstHalf = DaysOfFirstHalf + ?(Hours > 0, 1, 0);
					
				EndDo; 
				
				For Counter = 16 To Day(EndOfMonth(CurrentDocument.RegistrationPeriod)) Do
					
				    RowTypeOfTime = "" + Selection["FirstTimeKind" + Counter] + ?(ValueIsFilled(Selection["SecondTimeKind" + Counter]), "/" + Selection["SecondTimeKind" + Counter], "") + ?(ValueIsFilled(Selection["ThirdTimeKind" + Counter]), "/" + Selection["ThirdTimeKind" + Counter], "");
					StringHours = "" + ?(Selection["FirstHours" + Counter] = 0, "", Selection["FirstHours" + Counter]) + ?(ValueIsFilled(Selection["SecondTimeKind" + Counter]), "/" + Selection["SecondHours" + Counter], "") + ?(ValueIsFilled(Selection["ThirdTimeKind" + Counter]), "/" + Selection["ThirdHours" + Counter], "");
								 
					AreaDetails.Parameters["Char" + Counter] = RowTypeOfTime;			 
					AreaDetails.Parameters["AdditionalValue" + Counter] = StringHours;			 
								 
					Hours = ?(AddToWorkedTime(Selection["FirstTimeKind" + Counter]), Selection["FirstHours" + Counter], 0) 
							+ ?(AddToWorkedTime(Selection["SecondTimeKind" + Counter]), Selection["SecondHours" + Counter], 0) 
							+ ?(AddToWorkedTime(Selection["ThirdTimeKind" + Counter]), Selection["ThirdHours" + Counter], 0);
					HoursSecondHalf = HoursSecondHalf + Hours;
					DaysSecondHalf = DaysSecondHalf + ?(Hours > 0, 1, 0);
					
				EndDo; 
				
				For Counter = Day(EndOfMonth(CurrentDocument.RegistrationPeriod)) + 1 To 31 Do
					
				    AreaDetails.Parameters["Char" + Counter] = "X";			 
					AreaDetails.Parameters["AdditionalValue" + Counter] = "X";
					
				EndDo; 
				
				AreaDetails.Parameters.FirstHalfHour = FirstHalfHour;
				AreaDetails.Parameters.DaysOfFirstHalf = DaysOfFirstHalf;
				AreaDetails.Parameters.HoursSecondHalf = HoursSecondHalf;
				AreaDetails.Parameters.DaysSecondHalf = DaysSecondHalf;
				AreaDetails.Parameters.DaysPerMonth = DaysOfFirstHalf + DaysSecondHalf;
				AreaDetails.Parameters.HoursPerMonth = FirstHalfHour + HoursSecondHalf;
				
				SpreadsheetDocument.Put(AreaDetails);
			EndDo;
			
		Else
		
			Query.Text =
			"SELECT
			|	IndividualsDescriptionFullSliceLast.Surname,
			|	IndividualsDescriptionFullSliceLast.Name,
			|	IndividualsDescriptionFullSliceLast.Patronymic,
			|	TimesheetWorkedTimePerPeriod.Employee,
			|	TimesheetWorkedTimePerPeriod.Position,
			|	TimesheetWorkedTimePerPeriod.Employee.Code AS TabNumber,
			|	TimesheetWorkedTimePerPeriod.TimeKind1,
			|	TimesheetWorkedTimePerPeriod.Hours1,
			|	TimesheetWorkedTimePerPeriod.Days1,
			|	TimesheetWorkedTimePerPeriod.TimeKind2,
			|	TimesheetWorkedTimePerPeriod.Hours2,
			|	TimesheetWorkedTimePerPeriod.Days2,
			|	TimesheetWorkedTimePerPeriod.TimeKind3,
			|	TimesheetWorkedTimePerPeriod.Hours3,
			|	TimesheetWorkedTimePerPeriod.Days3,
			|	TimesheetWorkedTimePerPeriod.TimeKind4,
			|	TimesheetWorkedTimePerPeriod.Hours4,
			|	TimesheetWorkedTimePerPeriod.Days4,
			|	TimesheetWorkedTimePerPeriod.TimeKind5,
			|	TimesheetWorkedTimePerPeriod.Hours5,
			|	TimesheetWorkedTimePerPeriod.Days5,
			|	TimesheetWorkedTimePerPeriod.TimeKind6,
			|	TimesheetWorkedTimePerPeriod.Hours6,
			|	TimesheetWorkedTimePerPeriod.Days6
			|FROM
			|	Document.Timesheet.WorkedTimePerPeriod AS TimesheetWorkedTimePerPeriod
			|		LEFT JOIN InformationRegister.IndividualsDescriptionFull.SliceLast(&RegistrationPeriod, ) AS IndividualsDescriptionFullSliceLast
			|		ON TimesheetWorkedTimePerPeriod.Employee.Ind = IndividualsDescriptionFullSliceLast.Ind
			|WHERE
			|	TimesheetWorkedTimePerPeriod.Ref = &Ref
			|
			|ORDER BY
			|	TimesheetWorkedTimePerPeriod.LineNumber";
			
			Selection = Query.Execute().Select();		
				
			NPP = 0;
			While Selection.Next() Do
				NPP = NPP + 1;
				AreaDetails.Parameters.SerialNumber = NPP;
				AreaDetails.Parameters.Fill(Selection);
				If ValueIsFilled(Selection.Surname) Then
					Initials = SmallBusinessServer.GetSurnameNamePatronymic(Selection.Surname, Selection.Name, Selection.Patronymic, True);
				Else
					Initials = "";
				EndIf;
				AreaDetails.Parameters.DescriptionEmployee = ?(ValueIsFilled(Initials), Initials, Selection.Employee);
				
				RowTypeOfTime = "" + Selection.TimeKind1 + ?(ValueIsFilled(Selection.TimeKind2), "/" + Selection.TimeKind2, "") + ?(ValueIsFilled(Selection.TimeKind3), "/" + Selection.TimeKind3, "") + ?(ValueIsFilled(Selection.TimeKind4), "/" + Selection.TimeKind4, "") + ?(ValueIsFilled(Selection.TimeKind5), "/" + Selection.TimeKind5, "") + ?(ValueIsFilled(Selection.TimeKind6), "/" + Selection.TimeKind6, "");
				StringHours = "" + ?(Selection.TimeKind1 = 0, "", Selection.Hours1) + ?(ValueIsFilled(Selection.TimeKind2), "/" + Selection.Hours2, "") + ?(ValueIsFilled(Selection.TimeKind3), "/" + Selection.Hours3, "") + ?(ValueIsFilled(Selection.TimeKind4), "/" + Selection.Hours4, "") + ?(ValueIsFilled(Selection.TimeKind5), "/" + Selection.Hours5, "") + ?(ValueIsFilled(Selection.TimeKind6), "/" + Selection.Hours6, "");
				
				AreaDetails.Parameters.Char1 = RowTypeOfTime;			 
				AreaDetails.Parameters.AdditionalValue1 = StringHours;					 
				
				AreaDetails.Parameters.HoursPerMonth = ?(AddToWorkedTime(Selection.TimeKind1), Selection.Hours1, 0) 
							+ ?(AddToWorkedTime(Selection.TimeKind2), Selection.Hours2, 0) 
							+ ?(AddToWorkedTime(Selection.TimeKind3), Selection.Hours3, 0) 
							+ ?(AddToWorkedTime(Selection.TimeKind4), Selection.Hours4, 0) 
							+ ?(AddToWorkedTime(Selection.TimeKind5), Selection.Hours5, 0) 
							+ ?(AddToWorkedTime(Selection.TimeKind6), Selection.Hours6, 0);
					
				AreaDetails.Parameters.DaysPerMonth = ?(AddToWorkedTime(Selection.TimeKind1), Selection.Days1, 0) 
							+ ?(AddToWorkedTime(Selection.TimeKind2), Selection.Days2, 0) 
							+ ?(AddToWorkedTime(Selection.TimeKind3), Selection.Days3, 0) 
							+ ?(AddToWorkedTime(Selection.TimeKind4), Selection.Days4, 0) 
							+ ?(AddToWorkedTime(Selection.TimeKind5), Selection.Days5, 0) 
							+ ?(AddToWorkedTime(Selection.TimeKind6), Selection.Days6, 0);
					
				SpreadsheetDocument.Put(AreaDetails);
			EndDo;
		
		EndIf; 			
		
		Heads = SmallBusinessServer.OrganizationalUnitsResponsiblePersons(CurrentDocument.Company, CurrentDocument.Date);
		FooterArea.Parameters.Fill(Heads);
		SpreadsheetDocument.Put(FooterArea);
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, CurrentDocument);
	
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction // PrintForm()

// Generate printed forms of objects
//
// Incoming:
//   TemplateNames    - String    - Names of layouts separated
//   by commas ObjectsArray  - Array    - Array of refs to objects that
//   need to be printed PrintParameters - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection - Values table - Generated
//   table documents OutputParameters       - Structure        - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, 
	
	PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "Timesheet") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "Timesheet", "Working hours accounting timesheet", PrintForm(ObjectsArray, PrintObjects));
		
	EndIf;
	
	// parameters of sending printing forms by email
	SmallBusinessServer.FillSendingParameters(OutputParameters.SendingParameters, ObjectsArray, PrintFormsCollection);
	
EndProcedure

// Fills in Customer order printing commands list
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "Timesheet";
	PrintCommand.Presentation = NStr("en='Time recording sheet';ru='Табель учета рабочего времени'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
EndProcedure

#EndRegion

#EndIf