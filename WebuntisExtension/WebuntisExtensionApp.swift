//
//  WebuntisExtensionApp.swift
//  WebuntisExtension
//
//  Created by Christopher Haindl on 02.02.23.
//

import SwiftUI
import Foundation

@main
struct swiftui_menu_barApp: App {
    @State var observer: NSKeyValueObservation?
    var webuntis: WebUntisAPI = WebUntisAPI()

    var body: some Scene {

        MenuBarExtra("Webunits", systemImage: "clock.fill") {
            Webuntis()
                .environmentObject(webuntis)
                .environment(\.colorScheme, .light)
                .onAppear {
                observer = NSApplication.shared.observe(\.keyWindow) { x, y in
                    webuntis.currentDate = Date()
                }
            }
        }
            .menuBarExtraStyle(.window)
    }
}

struct Sizes
{
    static let cellWidth: CGFloat = 80
    static let cellHeight: CGFloat = 34
    static let cellSpacing: CGFloat = 4
    static let boxCornerRadius: CGFloat = 5
    static let menuBarHeight: CGFloat = 50
}

struct Webuntis: View
{
    @EnvironmentObject var webuntis: WebUntisAPI
    var body: some View
    {
        ZStack(alignment: .top)
        {
            VStack(spacing: 0)
            {
                var weekSchedule: Weekplan?
                {
                    var thisWeek: Weekplan? = nil
                    webuntis.weekSchedule.forEach()
                    {
                        week in
                        if week.mondayOfWeek == webuntis.mondayOfWeek
                        {
                            thisWeek = week
                        }
                    }
                    return thisWeek
                }

                TopBar()

                DateBar()

                Group
                {
                    if weekSchedule != nil
                    {
                        ScheduleDisplay(weekplan: weekSchedule!)
                            .padding(.vertical, Sizes.cellSpacing)
                    }
                    else if webuntis.isLoading
                    {
                        VStack
                        {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                    else if webuntis.beginFetchAt != nil
                    {
                        VStack
                        {
                            Spacer()
                            Button(action: { webuntis.gettingData() })
                            {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .resizable()
                                    .frame(width: 30, height: 30)
                                    .aspectRatio(contentMode: .fit)
                                    .foregroundColor(.white)
                            }
                                .buttonStyle(.borderless)
                            Text("Fehler während dem Erfassen von \(webuntis.beginFetchAt!.rawValue)")
                                .foregroundColor(.white)
                            Spacer()
                        }
                    }
                }
                    .frame(height: Sizes.cellHeight * 11 + Sizes.cellSpacing * 12)

                if webuntis.detailedLesson != nil
                {
                    InfoBox(lesson: webuntis.detailedLesson!)
                }

                if webuntis.optionsOpen
                {
                    OptionsView()
                        .transition(AnyTransition.asymmetric(insertion: .move(edge: .bottom), removal: .move(edge: .bottom)))
                }
                else
                {

                    MenuBar()
                        .transition(AnyTransition.asymmetric(insertion: .move(edge: .bottom), removal: .move(edge: .bottom)))
                }
            }
        }
    }
}

struct TopBar: View
{
    var body: some View
    {
        HStack
        {

            HStack(spacing: 0)
            {
                Image(systemName: "xmark.octagon.fill")
                    .foregroundColor(.black)
                Text("beenden")
                    .font(.caption)
            }
                .padding(3)
                .onTapGesture
            {
                NSApplication.shared.terminate(nil)
            }

            Spacer()
        }
            .background(Color.untisPrimary)
    }
}

struct MenuBar: View
{
    @EnvironmentObject var webuntis: WebUntisAPI
    var body: some View
    {
        HStack
        {
            DatePicker("", selection: $webuntis.displayedDay, displayedComponents: .date)
                .frame(width: 100)

            Spacer()

            Button("zurück")
            {
                webuntis.goBackAWeek()
            }

            Button(action: { webuntis.goToNow() })
            {
                Image(systemName: "calendar")
            }

            Button("vor")
            {
                webuntis.goForthAWeek()
            }

            Spacer()

            Button(action:
                {
                    withAnimation()
                    {
                        webuntis.optionsOpen = true
                    }
                })
            {
                Image(systemName: "gear")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .foregroundColor(Color.untisPrimary)
            }
                .buttonStyle(.borderless)
        }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .frame(height: Sizes.menuBarHeight)
            .background(Color.untisSecondary)
    }
}

struct OptionsView: View
{
    @EnvironmentObject var webuntis: WebUntisAPI

    @State var inputUser: String = ""
    @State var inputPW: String = ""

    var body: some View
    {
        VStack
        {
            HStack
            {
                TextField("Nutzername", text: $inputUser)
                    .textFieldStyle(.roundedBorder)
                SecureField("Passwort", text: $inputPW)
                    .textFieldStyle(.roundedBorder)
                Button(action:
                    {
                        webuntis.errorIn(.login, httpAnswer: "")
                        webuntis.optionsOpen = false
                        webuntis.username = inputUser
                        webuntis.password = inputPW
                    })
                {
                    Text("Speichern")
                        .padding(5)
                        .background()
                    {
                        RoundedRectangle(cornerRadius: 5)
                            .foregroundColor(Color.untisPrimary)
                    }
                }
                    .buttonStyle(.borderless)
            }
                .padding(.horizontal, 10)
        }
            .frame(height: Sizes.menuBarHeight)
            .background(Color.untisSecondary)
            .onAppear()
        {
            inputUser = webuntis.username
            inputPW = webuntis.password
        }
    }
}

struct DateBar: View
{
    @EnvironmentObject var webuntis: WebUntisAPI

    let calender = Calendar.current
    var mondayOfWeek: Date
    {
        let cl = Calendar.current
        var day = webuntis.displayedDay
        while cl.component(.weekday, from: day) != 2
        {
            day = cl.date(byAdding: .day, value: -1, to: day)!
        }
        return day
    }


    var body: some View
    {
        HStack(spacing: 0)
        {
            ForEach(0..<5)
            {
                dayIndex in

                ZStack
                {
                    Text("\(calender.component(.day, from: mondayOfWeek.addingTimeInterval(TimeInterval(dayIndex * 86400)))).\(calender.component(.month, from: mondayOfWeek.addingTimeInterval(TimeInterval(dayIndex * 86400))))")
                        .font(.system(size: 13, weight: .bold))
                }
                    .frame(width: Sizes.cellWidth, height: Sizes.cellHeight)

            }
        }
            .padding(.horizontal, Sizes.cellSpacing)
            .background(Color.untisPrimary)
    }
}

struct ScheduleDisplay: View
{
    @EnvironmentObject var webuntis: WebUntisAPI
    let weekSchedule: Weekplan
    let dateFormatter: DateFormatter
    let calender = Calendar.current

    init(weekplan: Weekplan)
    {
        weekSchedule = weekplan
        dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none
    }

    var body: some View
    {
        HStack(alignment: .top, spacing: Sizes.cellSpacing)
        {
            ForEach(0..<weekSchedule.days.count, id: \.self)
            {
                index in
                let weekday = weekSchedule.days[index]
                let excursion = getExcursion(weekday.hours)
                let holiday = getHoliday(dayOfWeek: index)
                
                if holiday != nil
                {
                    HolidayBox(holiday: getHoliday(dayOfWeek: index)!)
                        .frame(width: Sizes.cellWidth - Sizes.cellSpacing)
                }
                else if excursion != nil
                {
                    ExcurionBox(lesson: excursion!)
                }
                else
                {
                    VStack(spacing: 0)
                    {
                        VStack(spacing: Sizes.cellSpacing)
                        {
                            ForEach(0..<weekday.hours.count, id: \.self)
                            {
                                lesson in

                                if weekday.hours[lesson].count > 0
                                {
                                    let height: CGFloat = Sizes.cellHeight * CGFloat(weekday.hours[lesson][0].durationInHours) + Sizes.cellSpacing * CGFloat(weekday.hours[lesson][0].durationInHours - 1)
                                    LessonBox(lessons: weekday.hours[lesson])
                                        .frame(width: Sizes.cellWidth - Sizes.cellSpacing, height: height)
                                }
                                else
                                {
                                    Color.clear
                                        .frame(width: Sizes.cellWidth - Sizes.cellSpacing, height: Sizes.cellHeight)
                                }
                            }
                        }
                        Color.clear
                    }
                }
            }
        }
            .padding(.horizontal, Sizes.cellSpacing)
    }

    func getHoliday(dayOfWeek: Int) -> Holiday?
    {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"

        var returnHoliday: Holiday? = nil
        let date: Int = Int(dateFormatter.string(from: webuntis.mondayOfWeek.addingTimeInterval(TimeInterval(exactly: 86400 * dayOfWeek)!)))!
        webuntis.holidays.forEach { holiday in
            let startDate: Int = Int(dateFormatter.string(from: holiday.startDate))!
            let endDate: Int = Int(dateFormatter.string(from: holiday.endDate))!

            if startDate <= date && date <= endDate
            {
                returnHoliday = holiday
            }
        }
        return returnHoliday
    }

    func getExcursion(_ lessons: [[Lesson]]) -> Lesson?
    {
        if lessons.count < 1
        {
            return nil
        }
        var ls: Lesson? = nil
        lessons[0].forEach()
        {
            lesson in

            if lesson.isExcursion()
            {
                ls = lesson
                return
            }
        }
        return ls
    }
}

struct ExcurionBox: View
{
    @EnvironmentObject var webuntis: WebUntisAPI
    let lesson: Lesson
    var body: some View
    {
        ZStack
        {
            RoundedRectangle(cornerRadius: Sizes.boxCornerRadius)
                .foregroundColor(LessonSpecification.excursion.getColorOfSpecify().background)
                .onTapGesture {
                webuntis.detailedLesson = webuntis.detailedLesson == lesson ? nil : lesson
            }

            Text(lesson.teachers[0].name)
                .foregroundColor(LessonSpecification.excursion.getColorOfSpecify().foreground)
        }
    }
}

struct HolidayBox: View
{
    let holiday: Holiday
    var body: some View
    {
        ZStack
        {
            RoundedRectangle(cornerRadius: Sizes.boxCornerRadius)
                .foregroundColor(LessonSpecification.holiday.getColorOfSpecify().background)
                .frame(width: Sizes.cellWidth - Sizes.cellSpacing)

            Text(holiday.longName)
                .lineLimit(1)
                .frame(width: 200)
                .foregroundColor(LessonSpecification.holiday.getColorOfSpecify().foreground)
                .rotationEffect(Angle(degrees: -90))
        }
    }
}

struct InfoBox: View
{
    let lesson: Lesson

    private var teachersString: String
    {
        var res = ""
        for i in 0..<lesson.teachers.count
        {
            res += lesson.teachers[i].longName
            if i < lesson.teachers.count - 1
            {
                res += ", "
            }
        }
        return res != "" ? res : "keine"
    }
    private var hourString: String
    {
        var res = "\(lesson.hourIndex). Stunde"

        if lesson.durationInHours > 1
        {
            res += " - \(lesson.hourIndex + lesson.durationInHours - 1). Stunde"
        }

        res += " | \(lesson.timeAsString().0) Uhr - \(lesson.timeAsString().1) Uhr"

        return res != "" ? res : "keine"
    }
    private var klassenString: String
    {
        var res = ""
        for i in 0..<lesson.klassen.count
        {
            res += lesson.klassen[i].longName
            if i < lesson.klassen.count - 1
            {
                res += ", "
            }
        }
        return res != "" ? res : "keine"
    }
    private var roomsString: String
    {
        var res = ""
        for i in 0..<lesson.rooms.count
        {
            res += lesson.rooms[i].longName
            if i < lesson.rooms.count - 1
            {
                res += ", "
            }
        }
        return res != "" ? res : "keine"
    }

    var body: some View
    {
        VStack(alignment: .leading)
        {
            Text("\(lesson.subject.longName)")
                .font(.title2)
                .frame(height: 20)
            Text(hourString)
                .font(.callout)
            Divider()
            Text("Lehrer: " + teachersString)
                .frame(height: 15)
            Divider()
            Text("Klassen: " + klassenString)
                .frame(height: 15)
            Divider()
            Text("Räume: " + roomsString)
                .frame(height: 15)
        }
            .padding(5)
            .background(Color.untisSecondary)
    }
}

struct LessonBox: View
{
    @EnvironmentObject var webuntis: WebUntisAPI
    let lessons: [Lesson]

    var body: some View
    {
        HStack(spacing: Sizes.boxCornerRadius / 2)
        {
            ForEach(lessons, id: \.id)
            {
                lesson in

                ZStack
                {
                    RoundedRectangle(cornerRadius: Sizes.boxCornerRadius)
                        .foregroundColor(lesson.getColor())
                        .overlay()
                    {
                        if lessons.count > 1 && lesson.code == .irregular
                        {
                            Triangle()
                                .fill(lesson.code.getColorOfSpecify().background)
                                .mask(RoundedRectangle(cornerRadius: Sizes.boxCornerRadius))
                        }
                    }

                    VStack
                    {
                        Text(lesson.subject.name)
                            .foregroundColor(lesson.code.getColorOfSpecify().foreground)
                        Text(joinTeacherName(teachers: lesson.teachers))
                            .foregroundColor(lesson.code.getColorOfSpecify().foreground)
                    }
                }
                    .overlay()
                {
                    let calendar = Calendar.current
                    let date = webuntis.currentDate
                    let curTime: Int = Int(String(calendar.component(.hour, from: date)) + String(format: "%02d", calendar.component(.minute, from: date)))!
                    if webuntis.getMondayOfDateInWeek(date) == webuntis.mondayOfWeek &&
                        calendar.component(.weekday, from: date).advanced(by: -1) == lesson.dayOfWeek &&
                        lesson.code != .cancelled
                    {
                        if lesson.startTime < curTime && curTime < lesson.endTime
                        {
                            RoundedRectangle(cornerRadius: Sizes.boxCornerRadius)
                                .stroke(.red, lineWidth: 5)
                        }
                    }
                }
                    .onTapGesture {
                    webuntis.detailedLesson = webuntis.detailedLesson == lesson ? nil : lesson
                }
            }
        }
    }

    private func joinTeacherName(teachers: [Teacher]) -> String
    {
        var res = ""
        for i in 0..<teachers.count
        {
            res += teachers[i].name
            if i < teachers.count - 1
            {
                res += ", "
            }
        }
        return res
    }
}

extension Color
{
    static let untisPrimary: Color = Color.orange
    static let untisSecondary: Color = Color(hex: 0xe9e6f7)

    init(hex: Int, opacity: Double = 1.0) {
        let red = Double((hex & 0xff0000) >> 16) / 255.0
        let green = Double((hex & 0xff00) >> 8) / 255.0
        let blue = Double((hex & 0xff) >> 0) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
    init(hex: String, opacity: Double = 1.0) {
        let hexInt = Int(Double(hex) ?? 0)
        let red = Double((hexInt & 0xff0000) >> 16) / 255.0
        let green = Double((hexInt & 0xff00) >> 8) / 255.0
        let blue = Double((hexInt & 0xff) >> 0) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
extension Date
{
    func withoutTime() -> Date {
        let unixTimestamp = floor(self.timeIntervalSince1970 / 86400)
        return Date(timeIntervalSince1970: unixTimestamp * 86400)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}
