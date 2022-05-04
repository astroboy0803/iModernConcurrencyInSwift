import SwiftUI

struct TickerView: View {
    let selectedSymbols: [String]
    @EnvironmentObject var model: LittleJohnModel
    @Environment(\.presentationMode) var presentationMode
    @State var lastErrorMessage = "" {
        didSet { isDisplayingError = true }
    }
    @State var isDisplayingError = false

    var body: some View {
        List {
            Section(content: {
                ForEach(model.tickerSymbols, id: \.name) { symbolName in
                    HStack {
                        Text(symbolName.name)
                        Spacer()
                        .frame(maxWidth: .infinity)
                        Text(String(format: "%.3f", arguments: [symbolName.value]))
                    }
                }
            }, header: {
                Label(" Live", systemImage: "clock.arrow.2.circlepath")
                .foregroundColor(Color(uiColor: .systemGreen))
                .font(.custom("FantasqueSansMono-Regular", size: 42))
                .padding(.bottom, 20)
            })
        }
        .alert("Error", isPresented: $isDisplayingError, actions: {
            Button("Close", role: .cancel) { }
        }, message: {
            Text(lastErrorMessage)
        })
        .listStyle(PlainListStyle())
        .font(.custom("FantasqueSansMono-Regular", size: 18))
        .padding(.horizontal)
        .task {
            do {
                try await model.startTicker(selectedSymbols)
            } catch {
                if let error = error as? URLError, error.code == .cancelled {
                    return
                }
                
                lastErrorMessage = error.localizedDescription
            }
        }
        .onChange(of: model.tickerSymbols.count) { newValue in
            if newValue == .zero {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}
