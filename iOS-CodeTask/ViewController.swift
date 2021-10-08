import UIKit
//No need to import CloudKit as it will be a unnecessery dependency in modular design prospective
import CloudKit

//MARK: - Issue
/**
 - `ViewController` has alot of dependencies like `NewsFeedItem`, `Match`, `MatchAPIClient`,  `NewsAPIClient` and `ImageDataLoader`... etc., which makes it very rigidit, hard to extend, hard to test and hard to reuse.
 - We need to add reliable automated tests to this project to make sure we don't break logic or behaviour while refactoring this code.
 - Coding style issue: name `ViewController` is vague and doesn't implies any information
 */
//MARK: - Fix
/**
 - Refactor and split `ViewController` into tiny `MVCs` with logically related responsibilities will be a good start even though it's not the best solution here also we can use `MVP` or `MVVM`.
 - I recommend you to move the table view data source and delegate methods to a Swift extension on `ViewController`
 - I recommend to Change `ViewController` name to be something like `itemsListViewController` so that it will be more descriptive
 */
class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    //MARK: - Issue
    /**
     - tableView can be easily initialized from outside and this violates encapsulaztion
     */
    //MARK: - Fix
    /**
     - Add private access control keyword in front of it so it can be modified only inside this `ViewController` class
     */
    var tableView: UITableView?
    //MARK: - Issue
    /**
    - [Any] type is dangerous, it will require many force casting that may cause runtime error if we pass different types.
    - Violation of liskov substitution principle as if I try to sent any type other than `Match` or `NewsFeedItem`(which is considered `Any` type also) it will lead to runtime error.
    - Violation of Open/Closed principle because every time we add new data type we need to add another if statement to cast that `data` instance to that new type otherwise the app will crash.
     - Coding style issue: name `data` is vague and doesn't implies any information
     */
    //MARK: - Fix
    /**
     - I recommend you to refactor data model so we can achieve separation of concerns as `ViewController` getting too much responsibilities (Massive ViewController) which makes it hard to test, extend, maintain and reuse also it's talking directly to model layer so I think we need an intermediate presentation layer to reduce `ViewController`'s responsibilities like `Presenter` if we go with `MVP` pattern or `ViewModel` in case of `MVVM` pattern it doesn't matter which pattern we will use as long as it achieves the required separation of concerns.
     - Also we need a way to manage dequeuing and configuring cell out of the `ViewController` as `ViewController` just need a list of presentable data model so I suggest we need to create `CellController` protocol with all the shared logic needed to render any type of cell something like `func cell(_ tableView: UITableView) -> UITableViewCell`
     1- Create two cellController classes `MatchCellController` and `NewsCellController` that implementing `CellController` and receive equivalent data model as dependency to configure the cell with it
     2- In `cell` function configure and return the equivalent cell `MatchCardTableViewCell` in `MatchCellController` and `NewsItemTableViewCell` for `NewsCellController`
     3- Add property instance of type `CellController` in `ViewController` and call `cell` function on that instance in `cellForRowAt` to return UITableViewCell
     4- You could create separate `Composition Layer` that responsible for instantiate other modules and handling relationships between modules so that in `Composition Layer` we can handle the logic related to appending and initializing `data` array of `ViewController` with different types of cells
     - I recommend to Change data name to be something like `itemsListDataModel` so that it will be more descriptive
     */
    var data = [Any]()

    override func viewDidLoad() {
        super.viewDidLoad()
        //MARK: - Issue
        /**
         - I recommend you to keep UI setup in centralized place so that it's easier to manage and reason about and since we go with storyboard not UI by code I see it's better to setup UITableView in storyboard I know storyboard comes with it's cost but (trade-off) and UI by code more reliable and flexable.
         */
        //MARK: - Fix
        /**
         - If you will go with storyboard Remove `tableView = UITableView(frame:self.view.frame)` and `view?.addSubview(tableView!)` and setup UITableView from storyboard and capture IBOutlet for tableView here also remove `tableView!.delegate = self` and `tableView!.dataSource = self` and assign them from storyboard
         - if you prefer UI by code remove storyboard and setup your UI and it's constraint programmatically and change `tableView` to be lazy loaded and assign all configuration logic as closure to `tableView` lazy instance.
         - I recommend you to move this block into separate function to keep `viewDidLoad` clean and organized
         */
        tableView = UITableView(frame:self.view.frame)
        tableView!.delegate = self
        tableView!.dataSource = self
        //MARK: - Issue
        /**
         - Registering cell like that is fine (good work) but explicit strings like "MatchCardTableViewCell" are error-prone  I recommend to avoid it as possible as you can because if it's changed later you may forget to update here and this will lead to runtime error
         */
        //MARK: - Fix
        /**
         - I recommend you to create extension on UITableView for register cell by using ` String(describing: {{cell class}}.self)` as identifier to be more consistant and dynamic
         */
        self.tableView!.register(UINib(nibName: "MatchCardTableViewCell", bundle: nil), forCellReuseIdentifier: "MatchCardCell")
        self.tableView!.register(UINib(nibName: "NewsItemTableViewCell", bundle: nil), forCellReuseIdentifier: "NewsItemCell")
        view?.addSubview(tableView!)
        loadData()

    }

    //MARK: - Issue
    /**
     - the @objc and dynamic keywords allow you to use selectors and runtime dynamism in ways you would in Objective-C, also it allows swapping method implementations "swizzling" e.g. via the method_setImplemenation API, but I don't see the need to use such keywords here as we don't use selectors and no need for dynamic dispatch as dynamic dispatch comes at a cost, it's slower than static dispatch but we might use it when needed it's tradeoffs.
     */
    //MARK: - Fix
    /**
     - I recommend to remove `@objc` and `dynamic`
     */
    @objc dynamic func loadData() {
        //MARK: - Issues
        /**
         - `ViewController` Depend on concrete type `MockMatchLoader` and this violates Dependency inversion principle because the `ViewController` will be tightly-coupled with `MockMatchLoader` and depend on it and this makes `ViewController` hard to test, reuse and maintain also if we decide to change the API implementation we will have to break `ViewController` this will make our code rigidit.
         - `ViewController` shouldn't create it's own dependency because this is not `ViewController`'s responsibility to create and manage it's own dependency and this will make it hard to test.
         - Violation of single responsibility principle as `ViewController` has many reasons to change if add API, remove API etc..
         */
        //MARK: - Fix
        /**
         - I recommend you to apply dependency inversion principle to decouple `ViewController` from concrete API implementation, so instead of `ViewController` depends on concrete `MockMatchLoader` both of them depend on abstraction.
         1- Create protocol called `APIClient` with `loadItems(completion: @escaping (Result<[CellController], Error>) -> Void)` function.
         2- if we try to make `MockMatchLoader` implement `APIClient` directly we will face another issue `MockMatchLoader` is higher level than `ViewController` because it deals with high level operation agnostic of UI so it shouldn't depend on UI specific requirement `[CellController]` and in the same time we don't need `ViewController` to depend on concrete implementation details (e.g. `MockMatchLoader`or `NewsLoader`) directly so we need to adapt both unmatched interfaces to be able to decouple both of them and here is the role of `Adapter` pattern.
         3- Create `MatchAPIAdapter` that conforms to `APIClient` and add the required logic to map the array of `[Match]` into array of `[MatchCellController]` in `loadItems` function in the adapter .
         4- Inject instance of type `MockMatchLoader` into the adapter initializer to be able to call function `loadMatches` on it.
         5- Create `NewsAPIAdapter` that conforms to `APIClient` and add the required logic to map the array of `[NewsFeedItem]` into array of `NewsCellController` in `loadItems` function in the adapter.
         6- Inject instance of type `NewsLoader` into the `NewsAPIAdapter` initializer to be able to call function `loadNewsFeed` on it.
         7- Create instance property of type `APIClient` protocol  into `ViewController` so API interface is injected into `ViewController` instead of let `ViewController` creating it, and this solution will give us two benefits:
         - Make `ViewController` more testable as it's easy now to replace the real network implementation with the mocking one.
         - Easy to change network implementation without affecting `ViewController` because it depends on abstraction not concrete implementation.
         7- Since the adapters considered a composition details we can move it to composition layer so we can inject the proper adapter into `ViewController` and so we are get rid of branching and if else.
         */
        MockMatchLoader().loadMatches { (matches) in
            //MARK: - Issue
            /**
             /**
             - issues the same as in line 24
              */
             */
            //MARK: - Fix
            /**
             - solution as I metioned above line 30
             */
            var newData = [Any]()

            for match in matches {
                newData.append(match)
            }

            MockNewsLoader().loadNewsFeed { (newsFeedItems) in
                for newsFeedItem in newsFeedItems {
                    newData.append(newsFeedItem)
                }
                data = newData
                //MARK: - Issue
                /**
                 - `loadNewsFeed` function loading feeds in background thread and here we try to reload tableView in background thread so this might lead to runtime error.
                 */
                //MARK: - Fix
                /**
                 - Please dispatch to main thread whenever you need to update UI by calling it inside `DispatchQueue.main.async { }`
                 - I prefer to call `self.tableView?.reloadData()` in `didSet` propery observer of `data` array so I can grantee it will reload once array updated and also for readability purpose.
                 */
                
                self.tableView?.reloadData()
            }
        }
    }

    //MARK: - Issue
    /**
     - Architectural issue: `ViewController` has to be agnostic from any infrastructure implementation details like `URLSession` so calling download image here will tightly coupling `ViewController` with  `URLSession` and this will increase cost of change as `ViewController` doesn't care where image data comes from (e.g. cache or network).
     */
    //MARK: - Fix
    /**
     - I think we can apply dependency inversion by injecting a collaborator (interface) into `ViewController` that handling fetch image data, this way we are free to change the implementation or add more functionality (e.g. in-memory caching) on demand, without having to modify the `ViewController` (Open/Closed principle), it also facilitates testing as we don't need to add real network requests (which can be slow and flaky).
         1. Create protocol `ImageDataLoader` with function `loadImageData(url: URL)`.
         2. Add instance property of type `ImageDataLoader` to `ViewController`.
         3. Replace code that load image by calling `loadImageData(url: URL)` on that instance.
     */
    func downloadImage(url: URL, completion: @escaping ((UIImage) -> (Void))) {
        let downloadTask = URLSession.shared.dataTask(with: url) { (data, response, error) -> Void in
            //MARK: - Issue
            /**
             - Force wrapping may lead to crash if `data` is nil the same for `img`
             */
            //MARK: - Fix
            /**
             - You could use `guard let` or `if let` to unwrap optional `data` or `img` and change `UIImage` in `completion: @escaping ((UIImage) -> (Void))` to be optional `UIImage?`
             */
            let img = UIImage(data: data!)
            completion(img!)
        }
        downloadTask.resume()
    }

    //MARK: - Issue
    /**
     1- The open pracket in line 62 violate code styling
     2- `didReceiveMemoryWarning` function has nothing to do here
     */
    //MARK: - Fix
    /**
     1- It would be better to move open pracket in line 62 level up
     2- We can remove `didReceiveMemoryWarning` function
     */
    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        //MARK: - Issue
        /**
         - Semicolon violate code styling.
         */
        //MARK: - Fix
        /**
         - Recommend to remove semicolon.
         */
        return data.count;
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let rowData = data[indexPath.row]
        //MARK: - Issue
        /**
         - Violation of Open/Closed principle because every time we add new data type we need to add another if statement to cast rawData to that new type otherwise the app will crash as in line 151 we force-casting rowData to `NewsFeedItem` so our code won't be open for extension
         - Violation of liskov substitution principle because rawData here shows that it can handle `Any` type but this is not true it can only handle `Match` and `NewsFeedItem` if we pass a new type here like Double for example it will crash the app even though the `data` accepts it.
         */
        //MARK: - Fix
        /**
         - We need rowData to have specific type that represents exactly what the cell required
         */
        if rowData is Match {
            //MARK: - Issue
            /**
             - Dequeuing cell like that is fine (good work) but explicit strings like "MatchCardCell" are error-prone so I recommend to avoid it as possible as you can because if it's changed later you may forget to update here and this will lead to runtime error
             */
            //MARK: - Fix
            /**
             - I recommend you to create extension on UITableView for dequeue cell by using ` String(describing: {{cell class}}.self)` as identifier
             */
            let cell = tableView.dequeueReusableCell(withIdentifier: "MatchCardCell") as! MatchCardTableViewCell
            let match = rowData as! Match
            //MARK: - Issue
            /**
             - If cell goes offscreen the image download will complete downloading the image and this is might be wasting of resources especially the image won't be displayed
             */
            //MARK: - Fix
            /**
             - We need image cancellation mechanism like capture the task to use it to cancel image downloading later once it became offscreen we can call cancel method in `tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell)` and `tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath])`
             */
            downloadImage(url: match.teamHomeLogoURL) { (image) -> Void in
                //MARK: - Issue
                /**
                 - `downloadImage` function downloading image in background thread and here `cell.teamHomeImageView.image = image` we try to update UI (teamHomeImageView) in background thread so this might lead to runtime error.
                 */
                //MARK: - Fix
                /**
                 - Please dispatch to main thread whenever you need to update UI by calling line 137 inside `DispatchQueue.main.async { }`
                 */
                
                cell.teamHomeImageView.image = image
            }
            downloadImage(url: match.teamAwayLogoURL) { (image) -> Void in
                //MARK: - Issue
                /**
                 - `downloadImage` function downloading image in background thread and here `cell.teamHomeImageView.image = image` we try to update UI (teamHomeImageView) in background thread so this might lead to runtime error.
                 */
                //MARK: - Fix
                /**
                 - Please dispatch to main thread whenever you need to update UI by calling line 147, 148 inside `DispatchQueue.main.async { }`
                 */
                cell.teamHomeImageView.image = image
                cell.teamAwayImageView.image = image
            }

            cell.teamHomeNameLabel.text = match.teamHomeName
            cell.teamAwayNameLabel.text = match.teamAwayName
            //MARK: - Issue
            /**
             1- Enum is clear example of  Open/Closed principle violation as it will break if we need to add new case but it's fine if we make sure that no new cases will be added later.
             2- Show/Hide UI component is presentation logic which is more suitable to be in presentation layer also there are some duplications here have to be eliminated.
             3- You could use `prepareForReuse()` function to nullify UI components like UILabels texts and images so that we can avoid unexpected cell reuse behavior.
             */
            //MARK: - Fix
            /**
             1, 2- I recommend you to move Show/Hide UI component logic into presentation layer (e.g. `Presenter` for MVP or `ViewModel` for MVVM).
             `tableView.rowHeight = UITableView.automaticDimension`
             `tableView.estimatedRowHeight = { estimate height based on cell type }`
             */
            switch match.state {
            case .finished(let score):
                cell.kickoffDateLabel.isHidden = true
                cell.kickoffTimeLabel.isHidden = true
                cell.scoreLabel.isHidden = false
                cell.scoreLabel.text = score
            case .notStarted(let kickoffDate, let kickoffTime):
                cell.kickoffDateLabel.isHidden = false
                cell.kickoffDateLabel.text = kickoffDate
                cell.kickoffTimeLabel.isHidden = false
                cell.kickoffTimeLabel.text = kickoffTime
                cell.scoreLabel.isHidden = true
            }

            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "NewsItemCell") as! NewsItemTableViewCell
            //MARK: - Issue
            /**
             - Handling `downloadImage` here couples `ViewController` with implementation details as I mentioned above
             */
            //MARK: - Fix
            /**
             - You could replace `downloadImage` with calling `downloadImageData` function on instance of type `ImageDataLoader`
             */
            downloadImage(url: (rowData as! NewsFeedItem).imageURL) { (image) -> Void in
                //MARK: - Issue
                /**
                 - `downloadImage` function downloading image in background thread and here `cell.teamHomeImageView.image = image` we try to update UI (teamHomeImageView) in background thread so this might lead to runtime error.
                 */
                //MARK: - Fix
                /**
                 - Please dispatch to main thread whenever you need to update UI by calling line 147, 148 inside `DispatchQueue.main.async { }`
                 */
                cell.newsImageView.image = image
            }
            //MARK: - Issue
            /**
             - Force casting may cause runtime error if we pass different type other than `NewsFeedItem`
             */
            //MARK: - Fix
            /**
             - I recommend as I mentioned above to create `CellController` protocol to make data model more polymorphic so any new cell type has it's own cellController that implementing `CellController` protocol  and we could handle the logic related to appending and initializing `data` array of `ViewController` with different types of cells in `Composition Layer`
             */
            cell.previewLabel.text = (rowData as! NewsFeedItem).previewText

            return cell
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath : IndexPath) -> CGFloat {
        let rowData = data[indexPath.row]
        //MARK: - Issue
        /**
         1- Violation of Open/Closed principle.
         2- Calculating cell height based on cell type is presentation logic which is more suitable to be in presentation layer.
         3- I do not think fixing the height of the cell is a good idea, especially since the `NewsItemCell` contains a dynamic content UILabel that needs to calculate it's height at runtime
         */
        //MARK: - Fix
        /**
         1, 2- I recommend you to move calculating height logic into presentation layer (e.g. `Presenter` for MVP or `ViewModel` for MVVM) and remove `fatalError`.
         3- I recommend you to make UITableView cell height dynamic by adding those two lines in `viewDidLoad`
         `tableView.rowHeight = UITableView.automaticDimension`
         `tableView.estimatedRowHeight = { estimate height based on cell type }`
         */
        if rowData is Match {
            return 88
        } else if rowData is NewsFeedItem {
            return 104
        } else {
            fatalError()
        }
    }
}



