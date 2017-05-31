Function GetOverdueDaysCount(Val DateFrom, Val DateTo) Export
	
	DateFrom = BegOfDay(DateFrom);
	DateTo = BegOfDay(DateTo);
	
	While DateFrom<DateTo Do
		
		If Common.IsFreeDay(DateFrom) Then
			DateFrom = DateFrom + Common.DaySeconds();
		Else
			Break;
		EndIf;	
		
	EndDo;	
	
	Return (DateTo-DateFrom)/Common.DaySeconds();
	
EndFunction	

Function GetFineAmount(Customer,Amount,PaymentDate,PaidDate,FinePercent = Undefined,Date = Undefined) Export
	
	Days = GetOverdueDaysCount(PaymentDate,PaidDate);
	Return Amount*Days*?(FinePercent = Undefined,AccountingAtServer.GetFinePercent(Customer,Date),FinePercent)/100/CommonAtClientAtServerCached.GetYearDays(Date);
	
EndFunction	